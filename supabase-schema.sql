-- TranquiClean invoice log — run this once in Supabase → SQL Editor.

create table public.invoices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  invoice_number text not null,
  invoice_date date,
  terms_days integer,
  due_date date,
  client_name text,
  client_address text,
  client_email text,
  client_phone text,
  same_address boolean default true,
  service_address text,
  service_date date,
  items jsonb default '[]'::jsonb,
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

create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger invoices_set_updated_at
before update on public.invoices
for each row execute function public.set_updated_at();
