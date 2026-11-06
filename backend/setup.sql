-- Run once in your new Supabase project's SQL editor.
-- No student information, passwords, or secret keys belong in this repository.
begin;
create table public.desk_teachers(user_id uuid primary key references auth.users(id) on delete cascade);
create table public.desk_questions(
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null default auth.uid() references auth.users(id),
 student_name text not null check(length(trim(student_name)) between 1 and 80),
 title text not null check(length(trim(title)) between 1 and 120),
 consent boolean not null check(consent),
 status text not null default 'pending' check(status in ('pending','answered')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.desk_messages(
 id uuid primary key default gen_random_uuid(),question_id uuid not null references public.desk_questions(id) on delete cascade,
 author_id uuid not null default auth.uid() references auth.users(id),
 role text not null default 'student' check(role in ('student','teacher')),
 body text not null default '' check(length(body)<=6000),
 file_count smallint not null default 0 check(file_count between 0 and 3),
 created_at timestamptz not null default now(),check(length(trim(body))>0 or file_count>0)
);
create index on public.desk_questions(owner_id,created_at);
create index on public.desk_messages(question_id,created_at);
create index on public.desk_messages(author_id,created_at);

create function public.desk_is_teacher() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.desk_teachers t where t.user_id=(select auth.uid()));
$$;
create function public.desk_can_access(qid uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.desk_questions q where q.id=qid
 and q.created_at>now()-interval '30 days'
 and (q.owner_id=(select auth.uid()) or public.desk_is_teacher()));
$$;
revoke all on function public.desk_is_teacher(),public.desk_can_access(uuid) from public,anon;
grant execute on function public.desk_is_teacher(),public.desk_can_access(uuid) to authenticated;
alter table public.desk_teachers enable row level security;
alter table public.desk_questions enable row level security;
alter table public.desk_messages enable row level security;
revoke all on public.desk_teachers,public.desk_questions,public.desk_messages from anon,authenticated;
grant select on public.desk_teachers,public.desk_questions,public.desk_messages to authenticated;
grant insert(id,student_name,title,consent) on public.desk_questions to authenticated;
grant insert(id,question_id,body,file_count) on public.desk_messages to authenticated;
create policy teacher_self on public.desk_teachers for select to authenticated using(user_id=(select auth.uid()));
create policy question_read on public.desk_questions for select to authenticated using(public.desk_can_access(id));
create policy question_insert on public.desk_questions for insert to authenticated with check(owner_id=(select auth.uid()) and consent and coalesce((select auth.jwt())->>'is_anonymous','false')<>'true');
create policy message_read on public.desk_messages for select to authenticated using(public.desk_can_access(question_id));
create policy message_insert on public.desk_messages for insert to authenticated with check(author_id=(select auth.uid()) and public.desk_can_access(question_id) and coalesce((select auth.jwt())->>'is_anonymous','false')<>'true');

-- Database-side quotas cannot be bypassed by editing the browser code.
create function public.desk_guard_insert() returns trigger language plpgsql security definer set search_path='' as $$
begin
 perform pg_advisory_xact_lock(hashtext(auth.uid()::text));
 if auth.uid() is null then raise exception 'Sign in first'; end if;
 if TG_TABLE_NAME='desk_questions' then
  if (select count(*) from public.desk_questions where owner_id=auth.uid() and created_at>now()-interval '24 hours')>=8 then raise exception 'Daily question limit reached. Contact your teacher.';end if;
 else
  if (select count(*) from public.desk_messages where author_id=auth.uid() and created_at>now()-interval '1 hour')>=30 then raise exception 'Hourly message limit reached. Please try later.';end if;
  if (select count(*) from public.desk_messages where question_id=new.question_id)>=200 then raise exception 'Conversation is full. Start a new question.';end if;
  new.author_id:=auth.uid();new.role:=case when public.desk_is_teacher() then 'teacher' else 'student' end;
 end if;
 return new;
end;$$;
revoke all on function public.desk_guard_insert() from public,anon,authenticated;
create trigger question_quota before insert on public.desk_questions for each row execute function public.desk_guard_insert();
create trigger message_quota before insert on public.desk_messages for each row execute function public.desk_guard_insert();
create function public.desk_touch_question() returns trigger language plpgsql security definer set search_path='' as $$
begin update public.desk_questions set updated_at=now(),status=case when new.role='teacher' then 'answered' else 'pending' end where id=new.question_id;return new;end;$$;
revoke all on function public.desk_touch_question() from public,anon,authenticated;
create trigger message_updates_question after insert on public.desk_messages for each row execute function public.desk_touch_question();

-- Private bucket: never turn Public on. No client may overwrite or delete files.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('desk-files','desk-files',false,5242880,array['image/jpeg','image/png','image/webp','application/pdf']);
create function public.desk_file_access(object_name text,writing boolean) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.desk_messages m
 where split_part(object_name,'/',1)=m.question_id::text
 and split_part(object_name,'/',2)=m.id::text
 and object_name=m.question_id::text||'/'||m.id::text||'/'||split_part(object_name,'/',3)
 and split_part(object_name,'/',3)=any(array(select generate_series(0,m.file_count-1)::text))
 and public.desk_can_access(m.question_id)
 and (not writing or (m.author_id=(select auth.uid()) and m.created_at>now()-interval '15 minutes')));
$$;
revoke all on function public.desk_file_access(text,boolean) from public,anon;
grant execute on function public.desk_file_access(text,boolean) to authenticated;
create policy desk_upload on storage.objects for insert to authenticated with check(bucket_id='desk-files' and public.desk_file_access(name,true));
create policy desk_download on storage.objects for select to authenticated using(bucket_id='desk-files' and public.desk_file_access(name,false));
commit;

-- AFTER creating the teacher account under Authentication > Users:
-- insert into public.desk_teachers(user_id) values ('PASTE_TEACHER_USER_UUID_HERE');
-- Never give students a row in desk_teachers. Clients cannot modify this table.
