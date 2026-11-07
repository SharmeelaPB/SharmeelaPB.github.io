# Enable registration and teacher approval

This replaces manually enrolled students with a request-and-approve flow. The teacher's existing email/password login and teacher row are preserved. No passwords are stored in application tables or shown to the teacher.

## Required setup, in this order

1. In the existing Supabase project's SQL Editor, run **[approval-migration.sql](approval-migration.sql)**. This is a migration for an already configured question desk; do not run the original `setup.sql` again. The migration is repeat-safe and does not delete questions, messages, files, teacher accounts or registrations. Existing non-teacher accounts become pending and must be approved, including existing students.
2. Under **Authentication → Sign In / Providers → Email** (labels may vary), keep email/password enabled, allow new users to sign up, and turn **Confirm email off**. Keep anonymous sign-ins disabled. The form checks the public Auth settings and remains unavailable if confirmation is still required. Do not change the database rules to fix a registration error.
3. Refresh the [registration page](https://sharmeelapb.github.io/register.html). Create a test student account through this page. Sign in to the question page as that student. You must only see the waiting screen, not the question desk. Save its referral code.
4. Sign in separately as the teacher using her existing email and password. Under **Student access requests**, match the nickname, contact and code with the person through an established class channel. Click **Approve access**. The student uses **Check approval status** or signs in again to enter their own question desk.
5. Test with two separate student accounts. Each must see only their own records. Reject/revoke one account and verify that new question, message and download requests fail. Hold for review suspends access without deleting records. Test the teacher's upload and drawing replies as well. The migration has been checked locally against PostgreSQL-compatible fixtures; your hosted Auth/Storage integration still needs this end-to-end check.

## How usernames and referral codes work

Supabase Auth is email-based. To offer username/password login without SMTP, the app uses an internal alias `username@students.sharmeelapb.invalid` for newly registered students. This address is **not a working mailbox** and is never shown as a real contact address. The separate guardian/adult contact field is private to the applicant and teacher. It is not automatically verified. Email confirmation therefore must be off for this flow; teacher identity verification and approval are the access gate. The teacher keeps her existing real-email login.

Each account gets an immutable, random **SPB-…** referral code, generated in the database and protected by a unique constraint. It is a student account reference, not a referrer-tracking or marketing system. It is generated once per account, not on every login. Students can log in with their username **or** code and the same password. A public lookup converts a high-entropy code to an internal login alias only; it never returns a real contact email. The code does not grant access, approve an account or replace the password.

Only teachers can approve, reject or hold accounts using the server-checked review function. Clients cannot change approval status, their own referral code, or teacher roles. Review decisions are recorded in `desk_member_reviews`. The signed-in user can read their own approval status; teachers can see the queue. Question and storage access are checked against the current approval status, so an existing session cannot bypass rejection. Previously downloaded files cannot be recalled.

## Operational limits

No verification, invitation, approval or password-reset emails are sent. Password help must use the existing private class channel and Supabase dashboard account-management tools; do not publish passwords or use them in SQL. Automated account deletion/cleanup is not included. Regularly remove rejected/test accounts using the supported dashboard tools, taking care of associated records/files first.

Registration uses Supabase Auth's project-level rate limits; a malicious party can still create pending accounts and consume free-plan quota. Public registration should be monitored and disabled if abused. Configure a supported CAPTCHA and its frontend integration before advertising broadly outside the known class. This version relies on teacher approval and provider rate limits, and does not claim CAPTCHA coverage. Never approve solely because someone supplies a plausible name or email.

Pending/rejected users cannot read or submit questions or download attachments. They can read their own registration information and status. The current 30-day question access policy and manual file/record cleanup process remain in effect; member profiles and review history require operator-managed deletion. Configure a clear contact and retention policy before wider collection of minors' information.

Never put secret, service-role, database or management API keys into the public repository. The previously disclosed secret key must be revoked. The approval flow needs only the existing publishable key on the website.
