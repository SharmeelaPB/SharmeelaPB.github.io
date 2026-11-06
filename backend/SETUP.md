# Activate the free private question desk

The public website stays on GitHub Pages. The new `questions.html` page uses Supabase Auth, Postgres and a **private** Storage bucket. Until configured, it offers an explicit local-only demo; nothing is sent to the teacher.

## 1. Create a free project

Create a Supabase account and a project on the **Free** plan. Choose an appropriate nearby region. Save your database password in your password manager; never send it here or commit it. Free service has quotas and can pause after inactivity; monitor the dashboard and resume if necessary. Do not enable a paid upgrade unless you choose to.

## 2. Install the database rules

In the project's SQL Editor, run `setup.sql` **once**. It creates the questions/messages tables, teacher allowlist, account quotas and private file policies. It does not contain keys or user data. If it fails, transaction rollback prevents partial setup. Do not re-run it on an existing installation without reviewing a migration.

Keep the `desk-files` bucket private. The browser cannot grant itself teacher privileges, choose another student's owner ID, edit a message, forge a teacher role, or overwrite someone else's files. There are at most 3 fixed attachment slots per message and a 5 MB bucket limit per file. Each account is limited to 8 new questions per day and 30 messages per hour, with 200 messages per question. Supabase also applies Auth rate limits.

## 3. Create teacher and class accounts

In **Authentication → Users → Add user**, create the teacher account using an email she controls and a strong password. Use the dashboard's supported confirmed-account creation flow for manually provisioned accounts; no invitation email is required. Enter passwords directly into Supabase, not into source code or this chat.

Copy the teacher's User UID. In SQL Editor run:

```sql
insert into public.desk_teachers(user_id) values ('TEACHER_USER_UUID');
```

Create a separate account for each parent/guardian (or adult student). Send account access through a trusted private channel. **Do not reuse one student login across the class.** For under-18 students, a parent/guardian should manage the account and consent. The checkbox is an acknowledgment, not identity verification or legally verified parental consent.

Under Authentication configuration, **disable public signups and anonymous sign-ins**. There is deliberately no public registration form. This avoids unsolicited accounts, free-plan email delivery restrictions and anonymous storage abuse. Keep email/password sign-in enabled. Password resets and new access can be managed by the owner through the dashboard and established private communication. If adding self-service signup or password resets later, configure a production SMTP provider and verified redirects; Supabase's default mail service is restricted and not suitable for general class email delivery.

## 4. Connect the public page

From the project's Connect/API settings copy the **Project URL** and **publishable key** (or legacy **anon** key). These two values are intentionally browser-safe *only with the SQL access policies installed*. Fill `questions-config.json`:

```json
{
  "supabaseUrl": "https://YOUR_PROJECT.supabase.co",
  "publishableKey": "YOUR_PUBLISHABLE_KEY"
}
```

Never use `sb_secret_...`, a `service_role` JWT, the database connection string or a personal access token in this file. Those bypass the private access rules and must never appear in the public repository. Only the Project URL, public key and teacher user UUID are needed to finish this setup; no passwords or secret keys need to be shared in chat.

Set Auth Site URL to `https://sharmeelapb.github.io` and any needed redirect allowlist to `https://sharmeelapb.github.io/questions.html`. Push the config update. Sign in as teacher and then test with **two different student accounts**: each must only see its own questions, and direct requests to the other student's messages and attachments must fail. Teacher should see and answer both. Do this before sharing with students. The policies have not been exercised on your live project until this step is complete.

## 5. Pen / Wacom on a MacBook Air

Install the official Wacom driver for the tablet model and macOS version, connect it by USB or Bluetooth as supported, and set it to Pen mode. Sign in as teacher, open a question, and expand the writing pad. Write with the pen. Choose colour/size, Undo or Clear, and optionally Larger pad (exit fullscreen with Escape). Turn on Pen only to ignore touch/mouse input if the tablet reports stylus events as `pen`; leave it off if the driver exposes the pen as a mouse. Supported browsers send pressure information when the driver provides it, otherwise a constant line width is used.

The drawing becomes a PNG attachment when **Send message** is pressed. Students download it from their conversation. This is a writing pad, not handwriting-to-text or equation recognition. You can also write in your preferred Mac drawing application, export PNG/PDF, and attach that file. Browser pen input is implemented with Pointer Events; physical Wacom/macOS behaviour must be tested on her actual device.

## Privacy, file handling and retention

Accounts control access rather than shareable public student links. Tokens stay in tab-scoped session storage. Sign out on a shared computer. Only authenticated participants can download files. Downloads are served through the authenticated Storage endpoint and saved as attachments, rather than embedded in the page. No student content or credentials are published to GitHub.

Browser image uploads are decoded, size-checked, resized and re-encoded to remove metadata. PDF uploads receive a signature check. Server Storage enforces MIME/size and authorization; **it does not perform antivirus scanning or verify file contents**. A malicious client can bypass browser image sanitization. Do not treat downloaded files as trusted; production use with untrusted public signups would need a server quarantine/scanning pipeline. Class accounts are manually provisioned for this version.

Questions older than 30 days are inaccessible through the app's policies. This is **not automatic deletion**. The owner must delete expired files through Storage's supported API/dashboard first, then delete expired question rows (messages cascade) in SQL Editor:

```sql
select id from public.desk_questions where created_at < now() - interval '30 days';
-- Remove desk-files/<question UUID>/ files through Storage first, then:
delete from public.desk_questions where created_at < now() - interval '30 days';
```

Perform this regularly, and whenever a parent requests deletion. Do not delete `storage.objects` using SQL: use Storage's supported API/dashboard to remove the actual files. Provider backup retention may differ. Add scheduled cleanup before scaling. There is no email notification, AI service, student directory or public question feed. Replies appear in the inbox and student conversation after Refresh. No email delivery is claimed.

If a file upload fails after a message is saved, the page explicitly reports how many uploaded and asks the sender to reattach missing files. Original filenames are not stored. Text and file submission are not one atomic transaction. The frontend uses no external JavaScript package or font CDN.

Provide a parent-facing notice identifying the operator, provider and region, purpose and retention/deletion contact before collecting real student information. Confirm your consent arrangements for your jurisdiction. This starter does not claim legal compliance or managed-school readiness.
