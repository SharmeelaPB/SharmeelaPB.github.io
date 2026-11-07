-- Run this migration on the EXISTING question-desk project. Preserves existing data.
-- Repeat-safe. Install BEFORE enabling public registration.
begin;
create table if not exists public.desk_members(
 user_id uuid primary key references auth.users(id) on delete cascade,
 username text unique check(username is null or username ~ '^[a-z][a-z0-9_]{3,23}$'),
 student_name text not null default 'Student' check(length(student_name) between 1 and 80),
 guardian_contact text not null default '' check(length(guardian_contact)<=160),
 status text not null default 'pending' check(status in ('pending','approved','rejected')),
 created_at timestamptz not null default now(), reviewed_at timestamptz, reviewed_by uuid references auth.users(id)
);
create table if not exists public.desk_member_reviews(
 id uuid primary key default gen_random_uuid(),member_id uuid not null references public.desk_members(user_id) on delete cascade,
 teacher_id uuid not null references auth.users(id),status text not null,created_at timestamptz not null default now()
);
alter table public.desk_members enable row level security;
alter table public.desk_member_reviews enable row level security;
revoke all on public.desk_members,public.desk_member_reviews from anon,authenticated;
grant select on public.desk_members,public.desk_member_reviews to authenticated;
drop policy if exists member_read on public.desk_members;
create policy member_read on public.desk_members for select to authenticated using(user_id=(select auth.uid()) or public.desk_is_teacher());
drop policy if exists member_review_read on public.desk_member_reviews;
create policy member_review_read on public.desk_member_reviews for select to authenticated using(public.desk_is_teacher());

create or replace function public.desk_new_member() returns trigger language plpgsql security definer set search_path='' as $$
declare nickname text; contact text;
begin
 if exists(select 1 from public.desk_teachers where user_id=new.id) then return new;end if;
 nickname:=trim(coalesce(new.raw_user_meta_data->>'student_name','Student'));
 contact:=lower(trim(coalesce(new.email,'')));
 insert into public.desk_members(user_id,student_name,guardian_contact)
 values(new.id,nickname,contact) on conflict(user_id) do nothing;
 return new;
end;$$;
revoke all on function public.desk_new_member() from public,anon,authenticated;
drop trigger if exists desk_new_member_trigger on auth.users;
create trigger desk_new_member_trigger after insert on auth.users for each row execute function public.desk_new_member();
-- Existing student accounts also require approval. Existing teacher access is preserved.
insert into public.desk_members(user_id,guardian_contact) select id,coalesce(email,'') from auth.users
 where not exists(select 1 from public.desk_teachers t where t.user_id=auth.users.id)
 on conflict(user_id) do nothing;

create or replace function public.desk_is_approved() returns boolean language sql stable security definer set search_path='' as $$
 select public.desk_is_teacher() or exists(select 1 from public.desk_members m where m.user_id=(select auth.uid()) and m.status='approved');
$$;
revoke all on function public.desk_is_approved() from public,anon;
grant execute on function public.desk_is_approved() to authenticated;
create or replace function public.desk_can_access(qid uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.desk_questions q where q.id=qid and q.created_at>now()-interval '30 days'
 and (public.desk_is_teacher() or (q.owner_id=(select auth.uid()) and public.desk_is_approved())));
$$;
drop policy if exists question_insert on public.desk_questions;
create policy question_insert on public.desk_questions for insert to authenticated with check(owner_id=(select auth.uid()) and consent and public.desk_is_approved() and coalesce((select auth.jwt())->>'is_anonymous','false')<>'true');

create or replace function public.desk_review_member(member uuid,decision text) returns void language plpgsql security definer set search_path='' as $$
begin
 if not public.desk_is_teacher() then raise exception 'Teacher access required' using errcode='42501';end if;
 if decision not in ('approved','rejected','pending') then raise exception 'Invalid decision';end if;
 if exists(select 1 from public.desk_teachers where user_id=member) then raise exception 'Teacher accounts cannot be reviewed here';end if;
 perform 1 from public.desk_members where user_id=member for update;
 if not found then raise exception 'Registration not found';end if;
 update public.desk_members set status=decision,reviewed_at=now(),reviewed_by=auth.uid() where user_id=member;
 insert into public.desk_member_reviews(member_id,teacher_id,status) values(member,auth.uid(),decision);
end;$$;
revoke all on function public.desk_review_member(uuid,text) from public,anon;
grant execute on function public.desk_review_member(uuid,text) to authenticated;

-- Remove the unused legacy login lookup, if installed.
drop function if exists public.desk_resolve_code(text);
create or replace function public.desk_registration_ready() returns integer language sql immutable as $$select 1$$;
revoke all on function public.desk_registration_ready() from public;
grant execute on function public.desk_registration_ready() to anon,authenticated;
notify pgrst,'reload schema';
commit;
