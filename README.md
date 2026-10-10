# TeamFlow — production-oriented starter

A Next.js + Supabase starter for team projects, work-item tracking, monthly salary records, and payment history. It is a starter codebase, not a deployed/production-certified service.

## Features included
- Email/password login via Supabase Auth; no public sign-up page.
- Server-rendered dashboard; each member can read only their own work, salary, and payment rows.
- Admin role enforced in PostgreSQL Row Level Security (RLS), not just by hiding UI.
- Work records have `quantity × rate`; monthly salary is stored separately.
- Payment history supports cash, bank, bKash, Nagad, Rocket, or other.
- Admin overview with counts and outstanding monthly salary totals.

## Stack
- Next.js App Router + TypeScript
- Supabase Auth + PostgreSQL RLS
- Deploy Next.js to Vercel or another Node.js host; database/auth on Supabase

## Setup
1. Install Node.js 20+ and npm.
2. Create a Supabase project at https://supabase.com.
3. In Supabase SQL Editor, run `supabase/schema.sql`.
4. Create the first user in Supabase Dashboard → Authentication → Users (email/password). Copy the user's UUID.
5. Run this SQL in the Supabase SQL Editor, replacing UUID/name:
   ```sql
   insert into public.profiles(id, full_name, role)
   values ('AUTH-USER-UUID', 'Admin Name', 'admin');
   ```
6. For each team member, create a user in Supabase Auth, then insert a matching profile with `role='member'` and the same Auth UUID.
7. Copy `.env.example` to `.env.local` and fill in the Project URL and publishable/anon key from Supabase project settings. Never expose a `service_role` key in browser code or a `NEXT_PUBLIC_` variable.
8. Install and run:
   ```bash
   npm install
   npm run dev
   ```
9. Open http://localhost:3000.
10. Before deployment, set the same environment variables in your hosting provider, deploy the repository, configure the production URL in Supabase Auth URL Configuration, and enforce HTTPS.

## Important security / production checklist
- Disable public sign-ups in Supabase Auth. Admins should provision accounts.
- Enable email confirmation and configure password recovery/SMTP before inviting the team.
- Apply MFA to admin accounts where possible.
- Do not use the service-role key in the client. Keep it only in a trusted server environment if a future admin provisioning endpoint needs it.
- RLS is the data-access boundary. Keep policies enabled in production.
- The admin page currently provides a read-only overview; it deliberately does not expose unprotected browser-side create/update forms. Add admin-only server actions or route handlers with role checks and Zod validation for CRUD operations.
- Add server-side audit logging for all payroll edits; consider immutable payment records/reversals instead of deleting payments.
- Decide whether work payment is due only when `status='approved'`. This starter totals approved work items for display, but actual payment ledger reconciliation should be added before payroll use.
- Monthly salary `status` is a manually maintained summary. For partial payments, implement a transaction-safe RPC that recomputes paid amount and status from payment rows.
- Add automated tests, rate limiting/WAF, backups and restore testing, privacy policy, retention policy, and access review before storing real payroll data.
- This code has not been deployed, penetration-tested, or audited. Review and test with non-sensitive sample data first.

## Schema overview
- `profiles`: role and team member profile linked 1:1 to Supabase Auth.
- `projects`: project details, budget, deadline, status.
- `work_items`: member assignment, quantity, rate, status, due date.
- `salary_records`: monthly salary period and status.
- `payments`: payment ledger and method/reference.
- `audit_logs`: audit table (read restricted to admins; trusted server-side write path remains to implement).

## Important design note
A payment is a ledger event, not a boolean. Use one row per transfer. For accurate balances, add a database function that computes approved work earnings and monthly salary payable minus payments allocated to each source, all in a database transaction. Do not infer a payment is complete merely because a payment record exists.
