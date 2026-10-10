-- TeamFlow initial schema. Run in Supabase SQL Editor using a trusted project owner.
create extension if not exists pgcrypto;

create type public.app_role as enum ('admin','member');
create type public.work_status as enum ('assigned','in_progress','submitted','approved','rejected');
create type public.salary_status as enum ('pending','partially_paid','paid');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  role public.app_role not null default 'member',
  phone text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
create table public.projects (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  client_name text,
  description text,
  budget numeric(12,2) not null default 0 check (budget >= 0),
  deadline date,
  status text not null default 'active' check (status in ('planned','active','on_hold','completed','cancelled')),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);
create table public.work_items (
  id uuid primary key default gen_random_uuid(),
  project_id uuid references public.projects(id) on delete set null,
  member_id uuid not null references public.profiles(id),
  title text not null,
  description text,
  quantity numeric(12,2) not null default 1 check (quantity > 0),
  rate numeric(12,2) not null default 0 check (rate >= 0),
  status public.work_status not null default 'assigned',
  due_date date,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.salary_records (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles(id),
  period_start date not null,
  period_end date not null,
  amount numeric(12,2) not null check (amount >= 0),
  status public.salary_status not null default 'pending',
  paid_at timestamptz,
  note text,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  check (period_end >= period_start)
);
create table public.payments (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles(id),
  salary_record_id uuid references public.salary_records(id) on delete set null,
  work_item_id uuid references public.work_items(id) on delete set null,
  amount numeric(12,2) not null check (amount > 0),
  payment_date date not null default current_date,
  method text check (method is null or method in ('cash','bank','bkash','nagad','rocket','other')),
  reference text,
  note text,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  check (salary_record_id is not null or work_item_id is not null or note is not null)
);
create table public.audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid references public.profiles(id),
  action text not null,
  table_name text not null,
  record_id text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index work_items_member_idx on public.work_items(member_id, created_at desc);
create index work_items_project_idx on public.work_items(project_id);
create index salary_member_period_idx on public.salary_records(member_id, period_start desc);
create index payments_member_date_idx on public.payments(member_id, payment_date desc);

-- SECURITY DEFINER helpers avoid recursive RLS policies. Only trusted admins can set roles.
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'admin' and p.is_active = true);
$$;
create or replace function public.is_active_user()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.profiles p where p.id = (select auth.uid()) and p.is_active = true);
$$;
revoke all on function public.is_admin() from public;
revoke all on function public.is_active_user() from public;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.is_active_user() to authenticated;

alter table public.profiles enable row level security;
alter table public.projects enable row level security;
alter table public.work_items enable row level security;
alter table public.salary_records enable row level security;
alter table public.payments enable row level security;
alter table public.audit_logs enable row level security;

create policy "profiles read self or admin" on public.profiles for select to authenticated using (id = (select auth.uid()) or public.is_admin());
create policy "admin inserts profiles" on public.profiles for insert to authenticated with check (public.is_admin());
create policy "admin updates profiles" on public.profiles for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "admin deletes profiles" on public.profiles for delete to authenticated using (public.is_admin());

create policy "active users read projects" on public.projects for select to authenticated using (public.is_active_user());
create policy "admin creates projects" on public.projects for insert to authenticated with check (public.is_admin() and created_by = (select auth.uid()));
create policy "admin updates projects" on public.projects for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "admin deletes projects" on public.projects for delete to authenticated using (public.is_admin());

create policy "member reads own work admin reads all" on public.work_items for select to authenticated using (member_id = (select auth.uid()) or public.is_admin());
create policy "admin creates work" on public.work_items for insert to authenticated with check (public.is_admin() and created_by = (select auth.uid()));
create policy "admin updates work" on public.work_items for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "admin deletes work" on public.work_items for delete to authenticated using (public.is_admin());

create policy "member reads own salary admin reads all" on public.salary_records for select to authenticated using (member_id = (select auth.uid()) or public.is_admin());
create policy "admin creates salary" on public.salary_records for insert to authenticated with check (public.is_admin() and created_by = (select auth.uid()));
create policy "admin updates salary" on public.salary_records for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "admin deletes salary" on public.salary_records for delete to authenticated using (public.is_admin());

create policy "member reads own payments admin reads all" on public.payments for select to authenticated using (member_id = (select auth.uid()) or public.is_admin());
create policy "admin creates payments" on public.payments for insert to authenticated with check (public.is_admin() and created_by = (select auth.uid()));
create policy "admin updates payments" on public.payments for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "admin deletes payments" on public.payments for delete to authenticated using (public.is_admin());

create policy "admin reads audit logs" on public.audit_logs for select to authenticated using (public.is_admin());
-- No client-side insert/update/delete policies for audit_logs: add trusted server-side logging.

-- Create auth user in Supabase Auth first, then create their profile as project owner/admin.
-- Promote exactly one trusted account to admin after verifying its auth.users.id:
-- insert into public.profiles(id, full_name, role) values ('AUTH-USER-UUID', 'Your Admin Name', 'admin');
-- New member accounts: create user through Supabase Dashboard > Authentication, then insert role='member'.
