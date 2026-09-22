-- TranquiClean invoice log — run this in Supabase → SQL Editor.
-- Four tables: clients and services are standalone reusable catalogs;
-- invoices reference a client; invoice_line_items link an invoice to a
-- service (or a one-off custom description) with the qty/rate actually
-- billed on that invoice.

drop table if exists public.invoice_line_items;
drop table if exists public.services;
drop table if exists public.invoices;
drop table if exists public.clients;
drop table if exists public.business_profile;

-- ---------- clients ----------
create table public.clients (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  address text,
  email text,
  phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index clients_user_name_key on public.clients (user_id, lower(name));

alter table public.clients enable row level security;

create policy "Users can view their own clients"
  on public.clients for select
  using (auth.uid() = user_id);

create policy "Users can insert their own clients"
  on public.clients for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own clients"
  on public.clients for update
  using (auth.uid() = user_id);

create policy "Users can delete their own clients"
  on public.clients for delete
  using (auth.uid() = user_id);

-- ---------- services (reusable catalog, e.g. "Standard Clean" @ $120) ----------
create table public.services (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  default_rate numeric,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index services_user_name_key on public.services (user_id, lower(name));

alter table public.services enable row level security;

create policy "Users can view their own services"
  on public.services for select
  using (auth.uid() = user_id);

create policy "Users can insert their own services"
  on public.services for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own services"
  on public.services for update
  using (auth.uid() = user_id);

create policy "Users can delete their own services"
  on public.services for delete
  using (auth.uid() = user_id);

-- ---------- invoices ----------
create table public.invoices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  client_id uuid references public.clients(id) on delete set null,
  invoice_number text not null,
  invoice_date date,
  terms_days integer,
  due_date date,
  same_address boolean default true,
  service_address text,
  service_date date,
  discount numeric default 0,
  tax_rate numeric default 0,
  amount_paid numeric default 0,
  payment_info text,
  notes text,
  thank_you text,
  biz_tag text,
  biz_phone text,
  biz_email text,
  subtotal numeric default 0,
  tax numeric default 0,
  total numeric default 0,
  balance_due numeric default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, invoice_number)
);

alter table public.invoices enable row level security;

create policy "Users can view their own invoices"
  on public.invoices for select
  using (auth.uid() = user_id);

create policy "Users can insert their own invoices"
  on public.invoices for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own invoices"
  on public.invoices for update
  using (auth.uid() = user_id);

create policy "Users can delete their own invoices"
  on public.invoices for delete
  using (auth.uid() = user_id);

-- ---------- invoice_line_items (what was actually billed on an invoice) ----------
create table public.invoice_line_items (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references public.invoices(id) on delete cascade,
  service_id uuid references public.services(id) on delete set null,
  description text,
  hours numeric,
  rate numeric,
  amount numeric,
  position integer not null default 0,
  service_date date,
  created_at timestamptz not null default now()
);

create index invoice_line_items_invoice_id_idx on public.invoice_line_items (invoice_id);

alter table public.invoice_line_items enable row level security;

create policy "Users can view their own line items"
  on public.invoice_line_items for select
  using (exists (select 1 from public.invoices i where i.id = invoice_line_items.invoice_id and i.user_id = auth.uid()));

create policy "Users can insert their own line items"
  on public.invoice_line_items for insert
  with check (exists (select 1 from public.invoices i where i.id = invoice_line_items.invoice_id and i.user_id = auth.uid()));

create policy "Users can update their own line items"
  on public.invoice_line_items for update
  using (exists (select 1 from public.invoices i where i.id = invoice_line_items.invoice_id and i.user_id = auth.uid()));

create policy "Users can delete their own line items"
  on public.invoice_line_items for delete
  using (exists (select 1 from public.invoices i where i.id = invoice_line_items.invoice_id and i.user_id = auth.uid()));

-- ---------- business_profile (one row per user, auto-fills new invoices) ----------
create table public.business_profile (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique default auth.uid() references auth.users(id) on delete cascade,
  tagline text,
  phone text,
  email text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.business_profile enable row level security;

create policy "Users can view their own business profile"
  on public.business_profile for select
  using (auth.uid() = user_id);

create policy "Users can insert their own business profile"
  on public.business_profile for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own business profile"
  on public.business_profile for update
  using (auth.uid() = user_id);

create policy "Users can delete their own business profile"
  on public.business_profile for delete
  using (auth.uid() = user_id);

-- ---------- updated_at trigger ----------
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger clients_set_updated_at
before update on public.clients
for each row execute function public.set_updated_at();

create trigger services_set_updated_at
before update on public.services
for each row execute function public.set_updated_at();

create trigger invoices_set_updated_at
before update on public.invoices
for each row execute function public.set_updated_at();

create trigger business_profile_set_updated_at
before update on public.business_profile
for each row execute function public.set_updated_at();
