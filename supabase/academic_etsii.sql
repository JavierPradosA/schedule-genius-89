create extension if not exists "pgcrypto";

create table if not exists public.degrees (
  id text primary key,
  name text not null,
  abbreviation text,
  center text not null default 'ETSII',
  is_double_degree boolean not null default false,
  sort_order integer not null default 100,
  source_url text,
  created_at timestamptz not null default now()
);

create table if not exists public.subjects (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  name text not null,
  credits numeric(4,1),
  semester integer,
  created_at timestamptz not null default now()
);

create table if not exists public.subject_groups (
  id uuid primary key default gen_random_uuid(),
  subject_id uuid not null references public.subjects(id) on delete cascade,
  group_name text not null,
  professor text,
  campus text,
  capacity integer,
  created_at timestamptz not null default now(),
  unique(subject_id, group_name)
);

create table if not exists public.group_meetings (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.subject_groups(id) on delete cascade,
  weekday integer not null check (weekday between 1 and 7),
  start_time time not null,
  end_time time not null,
  classroom text,
  meeting_type text default 'theory',
  check (start_time < end_time)
);

create table if not exists public.degree_subjects (
  id uuid primary key default gen_random_uuid(),
  degree_id text not null references public.degrees(id) on delete cascade,
  subject_id uuid not null references public.subjects(id) on delete cascade,
  course integer not null check (course between 1 and 6),
  semester text not null check (semester in ('C1', 'C2', 'A')),
  type text not null default 'obligatoria' check (type in ('obligatoria', 'optativa')),
  mention text,
  created_at timestamptz not null default now(),
  unique(degree_id, subject_id)
);

create index if not exists idx_degrees_center_double
  on public.degrees(center, is_double_degree, sort_order);

create index if not exists idx_degree_subjects_degree_id
  on public.degree_subjects(degree_id);

create index if not exists idx_degree_subjects_subject_id
  on public.degree_subjects(subject_id);

create index if not exists idx_subject_groups_subject_id
  on public.subject_groups(subject_id);

create index if not exists idx_group_meetings_group_id
  on public.group_meetings(group_id);

create index if not exists idx_group_meetings_weekday_time
  on public.group_meetings(weekday, start_time, end_time);

insert into public.degrees (id, name, abbreviation, center, is_double_degree, sort_order)
values
  ('us-etsii-c', 'Grado en Ingeniería Informática - Ingeniería de Computadores', 'GII-C', 'ETSII', false, 10),
  ('us-etsii-s', 'Grado en Ingeniería Informática - Ingeniería del Software', 'GII-S', 'ETSII', false, 20),
  ('giti', 'Grado en Ingeniería Informática - Tecnologías Informáticas', 'GII-TI', 'ETSII', false, 30),
  ('us-etsii-ia', 'Grado en Ingeniería Informática - Inteligencia Artificial', 'GII-IA', 'ETSII', false, 40),
  ('us-etsii-sa', 'Grado en Ingeniería de la Salud', 'GIS', 'ETSII', false, 50)
on conflict (id) do update set
  name = excluded.name,
  abbreviation = excluded.abbreviation,
  center = excluded.center,
  is_double_degree = excluded.is_double_degree,
  sort_order = excluded.sort_order;

alter table public.degrees enable row level security;
alter table public.subjects enable row level security;
alter table public.subject_groups enable row level security;
alter table public.group_meetings enable row level security;
alter table public.degree_subjects enable row level security;

drop policy if exists "Permitir lectura publica de grados" on public.degrees;
drop policy if exists "Permitir lectura publica de asignaturas" on public.subjects;
drop policy if exists "Permitir lectura publica de grupos" on public.subject_groups;
drop policy if exists "Permitir lectura publica de horarios" on public.group_meetings;
drop policy if exists "Permitir lectura publica de asignaturas por grado" on public.degree_subjects;

create policy "Permitir lectura publica de grados"
on public.degrees for select to anon using (true);

create policy "Permitir lectura publica de asignaturas"
on public.subjects for select to anon using (true);

create policy "Permitir lectura publica de grupos"
on public.subject_groups for select to anon using (true);

create policy "Permitir lectura publica de horarios"
on public.group_meetings for select to anon using (true);

create policy "Permitir lectura publica de asignaturas por grado"
on public.degree_subjects for select to anon using (true);

grant usage on schema public to anon;
grant select on
  public.degrees,
  public.subjects,
  public.subject_groups,
  public.group_meetings,
  public.degree_subjects
to anon;
