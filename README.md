# Sharmeela PB — Mathematics Teacher

The teaching portfolio of **Sharmeela PB**, mathematics teacher.

**Website:** [sharmeelapb.github.io](https://sharmeelapb.github.io/)  
**Repository:** [SharmeelaPB/SharmeelaPB.github.io](https://github.com/SharmeelaPB/SharmeelaPB.github.io)

The portfolio is published through GitHub Pages.

## Student question desk

### Registration and approval

[Request student access](https://sharmeelapb.github.io/register.html) with a username/password, student nickname and parent/adult contact. Every applicant receives a unique database-generated referral code and remains pending until the teacher approves. Students can sign in with their username or referral code and password; the teacher keeps her existing email login. The teacher inbox includes an approval queue with approve, reject/revoke and hold actions.

**Activation required:** run the repeat-safe [approval migration](backend/approval-migration.sql) on the existing project and follow [approval setup](backend/APPROVAL-SETUP.md). Registration remains closed until the migration is installed and Auth is configured for username aliases. Existing teacher access is preserved; existing students must be approved. No secret keys are required.

[Open the question desk](https://sharmeelapb.github.io/questions.html).

Students can type messages, attach screenshots/photos/PDFs, and draw their working. The teacher can reply using the same tools, including a pressure-aware pen pad for a Wacom tablet on a MacBook Air. Each conversation supports multiple follow-ups. Physical Wacom support depends on the model, official macOS driver and browser; it has not yet been tested on the actual tablet.

The page includes a clearly labelled local demo. The live Supabase connection is configured. See [original activation instructions](backend/SETUP.md), the [database/access policies](backend/setup.sql), and the approval migration above. Approval setup supersedes the old manual-enrolment instructions. No student records are kept in GitHub.

Publish `index.html`, `style.css`, `script.js` and `.nojekyll` at the repository root. In repository Settings → Pages choose “Deploy from a branch”, then `main` and `/ (root)` and save. HTTPS should be enforced when available. The expected address after successful publication is `https://sharmeelapb.github.io/`.

This **portfolio-only repository is public**, as authorized for free GitHub Pages hosting. It contains no private maths-help application, credentials or student data.

This portfolio contains only the supplied name and occupation, general introductory copy, and three checked maths examples. It does not invent qualifications, teaching experience, class boards, testimonials or contact details. Add those only after the owner supplies them. The contact section currently directs existing students to their established teacher contact channel.

No frontend dependencies or installation required. For a local preview run `python -m http.server 3100 --bind 127.0.0.1` in this folder and open `http://localhost:3100`. The private question desk uses Supabase's hosted free-tier services once configured; quota limits and inactivity pausing apply.

The separate maths-help application is **not** deployed by this portfolio. GitHub Pages cannot run its Node server, AI requests, authentication or database. Add a link to that application after separately deploying it. Never upload `.env`, credentials, student records, the SQLite database or `.venv` to this repository.
