-- Supabase schema for syncing learned labels and grouped sequences
-- Run this in your Supabase SQL editor or via psql against your project.

-- Learned shape labels: keyed by geometry signature
create table if not exists public.learned_shapes (
  signature text primary key,
  label text not null,
  updated_at timestamptz not null default now()
);

-- Learned grouped sequences (e.g., clustered words/IDs)
create table if not exists public.learned_sequences (
  sequence text primary key,
  description text,
  updated_at timestamptz not null default now()
);

-- Useful indexes for partial searches (optional)
create index if not exists learned_sequences_gin_trgm on public.learned_sequences using gin (sequence gin_trgm_ops);
create index if not exists learned_shapes_label_trgm on public.learned_shapes using gin (label gin_trgm_ops);

-- Enable row-level security (add policies to match your auth model)
alter table public.learned_shapes enable row level security;
alter table public.learned_sequences enable row level security;
