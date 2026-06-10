-- Run this in Supabase SQL Editor to add pump session tracking

create table if not exists pump_sessions (
  id uuid primary key default gen_random_uuid(),
  family_id uuid references families(id) on delete cascade not null,
  date date not null,
  time text not null,
  ml integer,
  note text,
  created_by uuid references auth.users(id),
  created_at timestamptz default now()
);

alter table pump_sessions enable row level security;

create policy "Family members can manage pump sessions" on pump_sessions
  for all using (is_family_member(family_id))
  with check (is_family_member(family_id));
