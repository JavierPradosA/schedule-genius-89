-- 1. Esquema academico ETSII

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


-- 2. Seed corregido: solo asignaturas reales del plan, sin combinaciones de horario

-- Seed ETSII generado desde src/data/demoData.ts
-- Ejecuta primero supabase/academic_etsii.sql
begin;

insert into public.degrees (id, name, abbreviation, center, is_double_degree, sort_order)
values ('us-etsii-c', 'Grado en Ingeniería Informática - Ingeniería de Computadores', 'GII-C', 'ETSII', false, 10)
on conflict (id) do update set
  name = excluded.name,
  abbreviation = excluded.abbreviation,
  center = excluded.center,
  is_double_degree = excluded.is_double_degree,
  sort_order = excluded.sort_order;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('AE', 'AE', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-c', id, 1, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'AE'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C1)', 'Carlos Manuel Gomez Alvarez, Jose Carlos Molina Gomez, Jesus Racero Moreno'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AE'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T2 (C1)', 'Fernando Guerrero Lopez, Maria Del Rocio Heredia Lucas'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AE'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T3 (C1)', 'Ricardo Galan De Vega, Jose Miguel Vives Martinez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AE'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C1)', 'Carlos Manuel Gomez Alvarez, Jose Carlos Molina Gomez, Jesus Racero Moreno'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('ALN', 'ALN', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-c', id, 1, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C1)', 'Belen Medrano Garfia, Manuel Jesus Soto Prieto'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T2 (C1)', 'Olvido Delgado Garrido, Belen Medrano Garfia, Manuel Jesus Soto Prieto'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T3 (C1)', 'Olvido Delgado Garrido, Manuel Jesus Soto Prieto'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C1)', 'Belen Medrano Garfia, Manuel Jesus Soto Prieto'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('CED', 'CED', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-c', id, 1, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C1)', 'Manuel Merino Monge, Maria Del Carmen Baena Oliva, Jesus David Barrionuevo Vallecillo, Samuel Yanes Luis'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T2 (C1)', 'Maria Del Carmen Baena Oliva, Jesus David Barrionuevo Vallecillo, Samuel Yanes Luis'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T3 (C1)', 'Pablo Perez Garcia, Jesus David Barrionuevo Vallecillo, Antonio Algarin Perez, Maria Del Carmen Baena Oliva, Samuel Yanes Luis'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C1)', 'Manuel Merino Monge, Maria Del Carmen Baena Oliva, Jesus David Barrionuevo Vallecillo, Samuel Yanes Luis'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('CIN', 'CIN', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-c', id, 1, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'CIN'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C2)', 'Rosario Arriola Hernandez, Alvaro Dominguez Gutierrez, David Mellado Alcedo'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'CIN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CIN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CIN'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T2 (C2)', 'David Mellado Alcedo, Alvaro Dominguez Gutierrez, Rosario Arriola Hernandez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'CIN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CIN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CIN'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T3 (C2)', 'David Mellado Alcedo, Alvaro Dominguez Gutierrez, Rosario Arriola Hernandez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'CIN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CIN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CIN'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C2)', 'Rosario Arriola Hernandez, Alvaro Dominguez Gutierrez, David Mellado Alcedo'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'CIN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CIN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('E', 'E', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-c', id, 1, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'E'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C2)', 'Maria Teresa Gomez Gomez, Isabel Carlota Reymundo Dominguez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'E'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'E'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'E'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T2 (C2)', 'Maria Teresa Gomez Gomez, M Cristina Molero Del Rio, Isabel Carlota Reymundo Dominguez, Jose Carlos Castro Gomez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'E'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'E'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'E'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T3 (C2)', 'Alvaro Gomez Losada, Martina Fischetti'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'E'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'E'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'E'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C2)', 'Maria Teresa Gomez Gomez, Isabel Carlota Reymundo Dominguez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'E'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'E'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('EdC', 'EdC', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-c', id, 1, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C2)', 'Jose Rafael Luque Giraldez, Maria Del Carmen Baena Oliva, Daniel Fernandez Valderrama, Valentin Gutierrez Gil'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T2 (C2)', 'Maria Del Carmen Baena Oliva, Daniel Martin Fernandez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T3 (C2)', 'Pablo Perez Garcia, Manuel Merino Monge, Noelia Navarro Moreno'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C2)', 'Jose Rafael Luque Giraldez, Maria Del Carmen Baena Oliva, Daniel Fernandez Valderrama, Valentin Gutierrez Gil'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('FFI', 'FFI', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-c', id, 1, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C2)', 'Gonzalo Plaza Valtueña'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T2 (C2)', 'Alejandro Martinez Ros, Vicente Losada Torres, Faustino Palmero Acebedo'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T3 (C2)', 'Faustino Palmero Acebedo, Alejandro Martinez Ros, Raul Rodriguez Berral'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C2)', 'Gonzalo Plaza Valtueña'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('FP', 'FP', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-c', id, 1, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C1)', 'Manuel Carranza Garcia, Nicolas Sanchez Gomez, Jose Mariano Gonzalez Romano, Jorge Garcia Gutierrez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C2)', 'Manuel Carranza Garcia, Nicolas Sanchez Gomez, Jose Mariano Gonzalez Romano, Jorge Garcia Gutierrez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T2 (C1)', 'Jorge Garcia Gutierrez, Luis Miguel Soria Morillo, Belen Vega Marquez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T2 (C2)', 'Jorge Garcia Gutierrez, Jose Enrique Sanchez Lopez, Belen Ramos Gutierrez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T3 (C1)', 'Daniel Mateos Garcia, Antonia Maria Reina Quintero, Octavio Martin Diaz'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T3 (C2)', 'Daniel Mateos Garcia, Jose Enrique Sanchez Lopez, Nicolas Sanchez Gomez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C1)', 'Manuel Carranza Garcia, Nicolas Sanchez Gomez, Jose Mariano Gonzalez Romano, Jorge Garcia Gutierrez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C2)', 'Manuel Carranza Garcia, Nicolas Sanchez Gomez, Jose Mariano Gonzalez Romano, Jorge Garcia Gutierrez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('IMD', 'IMD', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-c', id, 1, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'IMD'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C1)', 'Maria Dolores Frau Garcia, Alvaro Torras Casas'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'IMD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IMD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IMD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IMD'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T2 (C1)', 'Javier Perera Lago, Alvaro Torras Casas, Maria Dolores Frau Garcia'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'IMD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IMD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IMD'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T3 (C1)', 'Jose Manuel Jimenez Cobano, Maria Dolores Frau Garcia'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'IMD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IMD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IMD'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C1)', 'Maria Dolores Frau Garcia, Alvaro Torras Casas'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'IMD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IMD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IMD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('AC', 'AC', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-c', id, 2, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C2)', 'Alvaro Ayuso Martinez, Manuel Rivas Perez, Belen Lopez Salamanca, Lourdes Duran Lopez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T2 (C2)', 'Belen Lopez Salamanca, Alejandro Gallego Romero, Juan Pedro Dominguez Morales, Juan Manuel Montes Sanchez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('ADDA', 'ADDA', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-c', id, 2, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C1)', 'Alfonso Bravo Llanos, Antonio Manuel Gutierrez Fernandez, Irene Barba Rodriguez, Ana Rodriguez Lopez, Diana Borrego Nuñez, Juan Alberto Gallardo Gomez, Jose Enrique Sanchez Lopez, Jose Manuel Sanchez Ruiz, Francisco Fernando De La Rosa Troyano'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C2)', 'Alfonso Bravo Llanos, Antonio Manuel Gutierrez Fernandez, Irene Barba Rodriguez, Ana Rodriguez Lopez, Diana Borrego Nuñez, Juan Alberto Gallardo Gomez, Jose Enrique Sanchez Lopez, Jose Manuel Sanchez Ruiz, Francisco Fernando De La Rosa Troyano'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T2 (C1)', 'Rafael Ceballos Guerrero, Antonio Manuel Gutierrez Fernandez, Carmelo Del Valle Sevillano, Francisco Javier Ferrer Troyano, Ana Rodriguez Lopez, Jose Manuel Sanchez Ruiz, Belen Ramos Gutierrez, Adrian Romero Flores'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T2 (C2)', 'Rafael Ceballos Guerrero, Antonio Manuel Gutierrez Fernandez, Carmelo Del Valle Sevillano, Francisco Javier Ferrer Troyano, Ana Rodriguez Lopez, Jose Manuel Sanchez Ruiz, Belen Ramos Gutierrez, Adrian Romero Flores'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('DSD', 'DSD', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-c', id, 2, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'DSD'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C1)', 'Maria Jose Avedillo De Juan, Angel Barriga Barros, Jose Maria Quintana Toledo, Maria Rosario Arjona Lopez, Jorge Fernandez Berni'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'DSD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'DSD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'DSD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'DSD'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T2 (C1)', 'Maria Jose Avedillo De Juan, Angel Barriga Barros, Jose Maria Quintana Toledo, Delia Velasco Montero'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'DSD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'DSD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'DSD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('IISSI1', 'IISSI1', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-c', id, 2, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'IISSI1'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C1)', 'Carlos Arevalo Maldonado, Daniel Ayala Hernandez, Maria Margarita Cruz Risco, Ana Belen Sanchez Jerez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'IISSI1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IISSI1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IISSI1'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T2 (C1)', 'Daniel Ayala Hernandez, Carlos Arevalo Maldonado, Maria Margarita Cruz Risco, Ana Belen Sanchez Jerez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'IISSI1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IISSI1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('IISSI2', 'IISSI2', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-c', id, 2, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'IISSI2'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C2)', 'Carlos Arevalo Maldonado, Maria Margarita Cruz Risco'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'IISSI2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IISSI2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IISSI2'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T2 (C2)', 'Daniel Ayala Hernandez, Maria Margarita Cruz Risco, Diego Manuel Galloso Fernandez, Jose Calderon Valdivia'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'IISSI2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IISSI2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('MD', 'MD', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-c', id, 2, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'MD'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C2)', 'Maria Dolores Frau Garcia, Manuel Gonzalez Regadera, Pilar Gomez-caminero Tellez, Maria Magdalena Fernandez Lebron'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'MD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'MD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'MD'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T2 (C2)', 'Yolanda De La Riva Moreno, Pilar Gomez-caminero Tellez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'MD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'MD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('RC', 'RC', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-c', id, 2, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'RC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C2)', 'Enrique Ostua Aranguena'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'RC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'RC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'RC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'RC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'RC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T2 (C2)', 'Maria Dolores Hernandez Velazquez, Eduardo Hidalgo Fort'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'RC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'RC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'RC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'RC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('SO', 'SO', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-c', id, 2, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'SO'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C1)', 'Jose Antonio Perez Castellanos'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'SO'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'SO'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'SO'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T2 (C1)', 'Jose Maria Luna Romera'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'SO'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'SO'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('TC', 'TC', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-c', id, 2, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'TC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C1)', 'Julio Barbancho Concejero, Noelia Navarro Moreno, German Cano Quiveu, Eduardo Hidalgo Fort, Iñigo Luis Monedero Goicoechea'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'TC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'TC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'TC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'TC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T2 (C1)', 'German Cano Quiveu, Carlos Leon De Mora, Eduardo Hidalgo Fort, Iñigo Luis Monedero Goicoechea, Noelia Navarro Moreno'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'TC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'TC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'TC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'TC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('AII', 'AII', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-c', id, 4, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'AII'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C2)', 'Vicente Carrillo Montero'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AII'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AII'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AII'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('ASC', 'ASC', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-c', id, 4, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'ASC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C2)', 'Maria Iluminada Baturone Castillo'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ASC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ASC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('C', 'C', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-c', id, 4, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'C'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C1)', 'Felix Gudiel Rodriguez, Victor Alvarez Solano, Jose Andres Armario Sampalo'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'C'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'C'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'C'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T2 (C1)', 'Jose Andres Armario Sampalo, Victor Alvarez Solano, Felix Gudiel Rodriguez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'C'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'C'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('EC', 'EC', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-c', id, 4, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'EC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C2)', 'Maria De Los Remedios Sillero Denamiel'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'EC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('LDH', 'LDH', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-c', id, 4, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'LDH'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C1)', 'Manuel Jesus Bellido Diaz'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'LDH'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'LDH'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('PGPI', 'PGPI', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-c', id, 4, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'PGPI'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C1)', 'Jose Rafael Luque Giraldez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'PGPI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'PGPI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('PHAE', 'PHAE', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-c', id, 4, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'PHAE'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C2)', 'Maria Jose Avedillo De Juan, Angel Barriga Barros'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'PHAE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'PHAE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('PID', 'PID', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-c', id, 4, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'PID'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C2)', 'Elena Camacho Aguilar, Maria Jose Jimenez Rodriguez, Belen Medrano Garfia'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'PID'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'PID'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('RA', 'RA', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-c', id, 4, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'RA'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C2)', 'Miguel Angel Ridao Carlini, Manuel Vargas Villanueva'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'RA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'RA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('SAC', 'SAC', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-c', id, 4, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'SAC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C2)', 'Santiago Joaquin Fernandez Scagliusi, Alberto Olmo Fernandez, Pablo Perez Garcia'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'SAC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'SAC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('SETR2', 'SETR2', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-c', id, 4, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'SETR2'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C1)', 'Daniel Casanueva Morato, Rafael Paz Vicente, Jose Antonio Rios Navarro, Angel Francisco Jimenez Fernandez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'SETR2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'SETR2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'SETR2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('SSII', 'SSII', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-c', id, 4, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'SSII'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C1)', 'Rafael Ceballos Guerrero, Angel Jesus Varela Vaca'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'SSII'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'SSII'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'SSII'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('T', 'T', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-c', id, 4, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'T'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C2)', 'Alejandro Millan Calderon'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'T'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'T'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'T'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'T'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('TIS', 'TIS', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-c', id, 4, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'TIS'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C1)', 'María Gloria Miro Amarante'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'TIS'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'TIS'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'TIS'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'TIS'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T2 (C1)', 'Juan Ignacio Guerrero Alonso, María Gloria Miro Amarante'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'TIS'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'TIS'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'TIS'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'TIS'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

insert into public.degrees (id, name, abbreviation, center, is_double_degree, sort_order)
values ('us-etsii-s', 'Grado en Ingeniería Informática - Ingeniería del Software', 'GII-S', 'ETSII', false, 20)
on conflict (id) do update set
  name = excluded.name,
  abbreviation = excluded.abbreviation,
  center = excluded.center,
  is_double_degree = excluded.is_double_degree,
  sort_order = excluded.sort_order;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('AE', 'AE', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 1, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'AE'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C2)', 'Mario Canivell Rodriguez, Maria Del Rocio Heredia Lucas, Antonio Placido Moreno Beltran, Marcos Toscano Bonilla'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AE'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T2 (C2)', 'Maria Del Rocio Heredia Lucas'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AE'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T3 (C2)', 'Ricardo Galan De Vega, Maria Del Carmen Velez Mendez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('ALN', 'ALN', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 1, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C2)', 'Juan Carlos Dana Jimenez, Luisa Maria Camacho Santana, Francisco Jose Planas Hernandez, Socrates Cuadri Crespo'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T2 (C2)', 'Juan Carlos Dana Jimenez, Luisa Maria Camacho Santana, Francisco Jose Planas Hernandez, Socrates Cuadri Crespo'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T3 (C2)', 'Olvido Delgado Garrido, Jose Manuel Jimenez Cobano, Socrates Cuadri Crespo'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('CED', 'CED', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 1, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C1)', 'Gemma Sanchez Anton, Francisco Perez Garcia'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T2 (C1)', 'Francisco Perez Garcia, Gemma Sanchez Anton'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T3 (C1)', 'Alejandro Millan Calderon, Pablo Perez Garcia, Maria Del Pilar Parra Fernandez, Antonio Algarin Perez, Samuel Dominguez Cid'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('CIN', 'CIN', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 1, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'CIN'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C1)', 'Delia Garijo Royo, Emmanuel Jean Briand, Jose Maria Ucha Enriquez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'CIN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CIN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CIN'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T2 (C1)', 'Rosario Arriola Hernandez, Beatriz Silva Gallardo, Emmanuel Jean Briand, Jose Maria Ucha Enriquez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'CIN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CIN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CIN'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T3 (C1)', 'David Mellado Alcedo, Maria Cruz Lopez De Los Mozos Martin, Jose Maria Ucha Enriquez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'CIN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CIN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('E', 'E', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 1, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'E'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C2)', 'David Galvez Ruiz, Antonio Navas Orozco, Martina Fischetti'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'E'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'E'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'E'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T2 (C2)', 'M Cristina Molero Del Rio, Diego Ponce Lopez, Isabel Carlota Reymundo Dominguez, Antonio Navas Orozco, Jose Carlos Castro Gomez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'E'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'E'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'E'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T3 (C2)', 'Pablo Jose Gerlach Mena, Antonio Navas Orozco, Isabel Carlota Reymundo Dominguez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'E'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'E'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('EdC', 'EdC', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 1, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C2)', 'Francisco Perez Garcia, Gemma Sanchez Anton'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T2 (C2)', 'Alberto Olmo Fernandez, Maria Del Pilar Parra Fernandez, Francisco Perez Garcia, Gemma Sanchez Anton'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T3 (C2)', 'Alejandro Millan Calderon, Santiago Joaquin Fernandez Scagliusi, Noelia Navarro Moreno, Daniel Martin Fernandez, Daniel Fernandez Valderrama, Valentin Gutierrez Gil'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('FFI', 'FFI', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 1, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C1)', 'Gonzalo Plaza Valtueña, Vicente Losada Torres'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T2 (C1)', 'Vicente Losada Torres, Jose Luis Mas Balbuena, Niurka Rodriguez Quintero'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T3 (C1)', 'Niurka Rodriguez Quintero, Raul Rodriguez Berral, Triana Czermak Alvarez, Alejandro Martinez Ros'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('FP', 'FP', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 1, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C1)', 'David Felipe Benavides Cuevas, Jose Angel Galindo Duarte, Belen Vega Marquez, Pablo Reina Jimenez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C2)', 'David Felipe Benavides Cuevas, Jose Angel Galindo Duarte, Nicolas Sanchez Gomez, Jose Enrique Sanchez Lopez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T2 (C1)', 'Jose Miguel Toro Bonilla, Daniel Mateos Garcia, Luis Miguel Soria Morillo, Pablo Reina Jimenez, Belen Vega Marquez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T2 (C2)', 'Jose Miguel Toro Bonilla, Daniel Mateos Garcia, Elena Enamorado Diaz, Nicolas Sanchez Gomez, Aitor Rodriguez Dueñas'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T3 (C1)', 'Antonia Maria Reina Quintero, Octavio Martin Diaz, Patricia Jimenez Aguirre, Juan Antonio Nepomuceno Chamorro'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T3 (C2)', 'Antonia Maria Reina Quintero, Manuel Carranza Garcia, María Dolores Acuña Garrido'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('IMD', 'IMD', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 1, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'IMD'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C1)', 'Amparo Osuna Lucena, Maria Magdalena Fernandez Lebron, Maria Dolores Frau Garcia'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'IMD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IMD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IMD'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T2 (C1)', 'Amparo Osuna Lucena, Maria Magdalena Fernandez Lebron, Maria Dolores Frau Garcia'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'IMD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IMD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IMD'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T3 (C1)', 'Alvaro Torras Casas, Amparo Osuna Lucena, Jose Manuel Jimenez Cobano'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'IMD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IMD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('AC', 'AC', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 2, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C2)', 'Belen Lopez Salamanca, Placido Fernandez Cuevas, Antonio Manuel Perez Peña, Miguel Angel Rodriguez Jodar, Daniel Cascado Caballero'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T2 (C2)', 'Antonio Manuel Perez Peña, Maria Teresa Serrano Gotarredona, Ignacio Garcia Vargas, Daniel Cascado Caballero, Placido Fernandez Cuevas'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T3 (C2)', 'Daniel Cascado Caballero, Antonio Manuel Perez Peña, Miguel Angel Rodriguez Jodar, Daniel Cagigas Muñiz, Ignacio Garcia Vargas, Belen Lopez Salamanca'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('ADDA', 'ADDA', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 2, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C1)', 'Jose Miguel Toro Bonilla, Irene Barba Rodriguez, Rafael Ceballos Guerrero, Diana Borrego Nuñez, Alfonso Bravo Llanos, Francisco Fernando De La Rosa Troyano'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C2)', 'Jose Miguel Toro Bonilla, Irene Barba Rodriguez, Rafael Ceballos Guerrero, Diana Borrego Nuñez, Alfonso Bravo Llanos, Francisco Fernando De La Rosa Troyano'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T2 (C1)', 'Daniel Ayala Hernandez, Irene Barba Rodriguez, Antonio Martinez Rojas, Carmelo Del Valle Sevillano, Rafael Ceballos Guerrero, Diana Borrego Nuñez, Francisco Fernando De La Rosa Troyano'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T2 (C2)', 'Daniel Ayala Hernandez, Irene Barba Rodriguez, Antonio Martinez Rojas, Carmelo Del Valle Sevillano, Rafael Ceballos Guerrero, Diana Borrego Nuñez, Francisco Fernando De La Rosa Troyano'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T3 (C1)', 'Irene Barba Rodriguez, Jesus Moreno Leon, Jose Manuel Sanchez Ruiz, Rafael Ceballos Guerrero, Ana Rodriguez Lopez, Francisco Fernando De La Rosa Troyano, Francisco Javier Ferrer Troyano'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T3 (C2)', 'Irene Barba Rodriguez, Jesus Moreno Leon, Jose Manuel Sanchez Ruiz, Rafael Ceballos Guerrero, Ana Rodriguez Lopez, Francisco Fernando De La Rosa Troyano, Francisco Javier Ferrer Troyano'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('AISS', 'AISS', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 2, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'AISS'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C2)', 'Sergio Segura Rueda, Irene Bedilia Estrada Torres, Alfonso Eduardo Marquez Chamorro'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AISS'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AISS'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AISS'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T2 (C2)', 'Adrian Romero Flores, Sergio Segura Rueda, Irene Bedilia Estrada Torres, Alfonso Eduardo Marquez Chamorro'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AISS'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AISS'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AISS'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T3 (C2)', 'Adela Del Rio Ortega, Adrian Romero Flores, Ana Belen Sanchez Jerez, Jesus Moreno Leon, Alfonso Eduardo Marquez Chamorro, Antonio Ruiz Cortes'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AISS'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AISS'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('IISSI1', 'IISSI1', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 2, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'IISSI1'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C1)', 'Alejandro Fernandez-montes Gonzalez, Alfonso Eduardo Marquez Chamorro'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'IISSI1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IISSI1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IISSI1'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T2 (C1)', 'Francisco Javier Ortega Rodriguez, Carlos Arevalo Maldonado'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'IISSI1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IISSI1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IISSI1'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T3 (C1)', 'Alfonso Eduardo Marquez Chamorro, Damian Fernandez Cerero'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'IISSI1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IISSI1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('IISSI2', 'IISSI2', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 2, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'IISSI2'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C2)', 'Damian Fernandez Cerero, Alejandro Fernandez-montes Gonzalez, Luis Miguel Soria Morillo, Fermin Cruz Mata, Juan Antonio Alvarez Garcia'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'IISSI2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IISSI2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IISSI2'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T2 (C2)', 'Alejandro Fernandez-montes Gonzalez, Juan Antonio Alvarez Garcia, Fermin Cruz Mata'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'IISSI2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IISSI2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IISSI2'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T3 (C2)', 'Francisco Jose Dominguez Mayo, Octavio Martin Diaz, Fermin Cruz Mata, Diego Manuel Galloso Fernandez, Manuel Jesus Jimenez Navarro, Damian Fernandez Cerero, Alejandro Fernandez-montes Gonzalez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'IISSI2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IISSI2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('LI', 'LI', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 2, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'LI'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C1)', 'Jesus Giraldez Cru'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'LI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'LI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'LI'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T2 (C1)', 'Alvaro Romero Jimenez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'LI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'LI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'LI'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T3 (C1)', 'Maria Carmen Graciani Diaz, Jose Luis Pro Martin'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'LI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'LI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('MD', 'MD', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 2, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'MD'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C2)', 'Amparo Osuna Lucena, Victor Diaz Gil, Alvaro Torras Casas, Jose Ramon Portillo Fernandez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'MD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'MD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'MD'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T2 (C2)', 'Maria Magdalena Fernandez Lebron, Victor Diaz Gil, Maria Dolores Frau Garcia, Jose Ramon Portillo Fernandez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'MD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'MD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'MD'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T3 (C2)', 'Jose Manuel Jimenez Cobano, Alvaro Torras Casas, Victor Diaz Gil, Jose Ramon Portillo Fernandez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'MD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'MD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('RC', 'RC', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 2, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'RC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C1)', 'Enrique Dorronzoro Zubiete, Noelia Navarro Moreno, Maria Dolores Hernandez Velazquez, Maria Del Carmen Romero Ternero, Sergio Martin Guillen'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'RC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'RC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'RC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'RC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'RC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T2 (C1)', 'Sergio Martin Guillen, Maria Dolores Hernandez Velazquez, Enrique Dorronzoro Zubiete'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'RC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'RC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'RC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'RC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'RC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T3 (C1)', 'Maria Dolores Hernandez Velazquez, Adrian Estrada Perez, Noelia Navarro Moreno, Jesus David Barrionuevo Vallecillo, Sergio Martin Guillen, Samuel Yanes Luis'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'RC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'RC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'RC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'RC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('SO', 'SO', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 2, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'SO'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C1)', 'Pablo Neira Ayuso, David Gutierrez Aviles, Jose Antonio Perez Castellanos'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'SO'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'SO'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'SO'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T2 (C1)', 'Rafael Corchuelo Gil, Pablo Neira Ayuso'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'SO'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'SO'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'SO'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T3 (C1)', 'David Gutierrez Aviles, Leticia Morales Trujillo'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'SO'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'SO'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('ASR', 'ASR', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 3, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'ASR'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C2)', 'Daniel Martin Fernandez, Jaime Benjumea Mondejar, Jesus David Barrionuevo Vallecillo, Octavio Rivera Romero, Sergio Martin Guillen, Alejandro Casado Galan'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ASR'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ASR'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ASR'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ASR'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ASR'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ASR'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T2 (C2)', 'Jaime Benjumea Mondejar, Octavio Rivera Romero, Enrique Dorronzoro Zubiete, Daniel Martin Fernandez, Jesus David Barrionuevo Vallecillo, Sergio Martin Guillen'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ASR'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ASR'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ASR'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ASR'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ASR'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T3 (C2)', 'Adrian Estrada Perez, Antonio Martin Montes, Francisco Jose Anillo Carrasco, Noelia Navarro Moreno'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ASR'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ASR'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ASR'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ASR'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ASR'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('DP1', 'DP1', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 3, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'DP1'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C1)', 'José Antonio Parejo Maestre, Ana Belen Sanchez Jerez, Irene Bedilia Estrada Torres, Jose M Garcia Rodriguez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'DP1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'DP1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'DP1'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T2 (C1)', 'Jose M Garcia Rodriguez, José Antonio Parejo Maestre, Ana Belen Sanchez Jerez, Irene Bedilia Estrada Torres'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'DP1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'DP1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'DP1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'DP1'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T3 (C1)', 'Carlos Guillermo Müller Cejas, José Antonio Parejo Maestre, Irene Bedilia Estrada Torres'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'DP1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'DP1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('DP2', 'DP2', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 3, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'DP2'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C2)', 'Rafael Corchuelo Gil, Adrian Romero Flores, Patricia Jimenez Aguirre, Manuel Jesus Jimenez Navarro'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'DP2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'DP2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'DP2'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T2 (C2)', 'Patricia Jimenez Aguirre, Adrian Romero Flores, Manuel Jesus Jimenez Navarro'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'DP2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'DP2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'DP2'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T3 (C2)', 'Rafael Corchuelo Gil, Patricia Jimenez Aguirre, Manuel Jesus Jimenez Navarro'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'DP2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'DP2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('IA', 'IA', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 3, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'IA'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C2)', 'Alvaro Romero Jimenez, Manuel Soriano Trigueros, Ignacio Perez Hurtado De Mendoza, Eduardo Perez Perdomo'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'IA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IA'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T2 (C2)', 'Juan Galan Paez, Manuel Soriano Trigueros, Ignacio Perez Hurtado De Mendoza, Gabriel Chaves Benitez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'IA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IA'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T3 (C2)', 'Pedro Almagro Blanco, Manuel Soriano Trigueros, Gabriel Chaves Benitez, Eduardo Perez Perdomo'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'IA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('IR', 'IR', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 3, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'IR'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C1)', 'Beatriz Bernardez Jimenez, Pablo Fernandez Montes, Adela Del Rio Ortega, Octavio Martin Diaz'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'IR'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IR'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IR'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T2 (C1)', 'Pablo Fernandez Montes, Adela Del Rio Ortega, Beatriz Bernardez Jimenez, Octavio Martin Diaz'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'IR'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IR'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IR'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T3 (C1)', 'Adela Del Rio Ortega, Beatriz Bernardez Jimenez, Amador Duran Toro, Octavio Martin Diaz, Irene Bedilia Estrada Torres'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'IR'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IR'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('MSN', 'MSN', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 3, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'MSN'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C1)', 'Victor Alvarez Solano, Maria Teresa Gonzalez Montesino, Juan Vicente Gutierrez Santacreu, Alvaro Dominguez Gutierrez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'MSN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'MSN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'MSN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'MSN'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T2 (C1)', 'Victor Alvarez Solano, Alvaro Dominguez Gutierrez, Maria Teresa Gonzalez Montesino, Juan Vicente Gutierrez Santacreu, Pedro Gomez De Terreros Oramas, Pilar Gomez-caminero Tellez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'MSN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'MSN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'MSN'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T3 (C1)', 'Victor Alvarez Solano, Miguel Navarro Castro, Pablo Terron Quintero, Alvaro Dominguez Gutierrez, Pedro Gomez De Terreros Oramas, Juan Vicente Gutierrez Santacreu, Pilar Gomez-caminero Tellez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'MSN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'MSN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('MVG', 'MVG', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 3, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'MVG'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C2)', 'Maria Nieves Atienza Martinez, Pilar Gomez-caminero Tellez, Belen Medrano Garfia, Francisco Jose Planas Hernandez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'MVG'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'MVG'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'MVG'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T2 (C2)', 'Belen Medrano Garfia, Pilar Gomez-caminero Tellez, Maria Del Rocio Gonzalez Diaz, Francisco Jose Planas Hernandez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'MVG'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'MVG'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'MVG'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T3 (C2)', 'Belen Medrano Garfia, Pilar Gomez-caminero Tellez, Maria Nieves Atienza Martinez, Francisco Jose Planas Hernandez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'MVG'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'MVG'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('PSG1', 'PSG1', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 3, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'PSG1'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C1)', 'Francisco Jose Dominguez Mayo, Manuel Mejias Risoto, María Dolores Acuña Garrido, Javier Jesus Gutierrez Rodriguez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'PSG1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'PSG1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'PSG1'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T2 (C1)', 'Manuel Mejias Risoto, María Dolores Acuña Garrido, Miguel Angel Olivero Gonzalez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'PSG1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'PSG1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'PSG1'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T3 (C1)', 'Francisco Jose Dominguez Mayo, María Dolores Acuña Garrido, Javier Jesus Gutierrez Rodriguez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'PSG1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'PSG1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('PSG2', 'PSG2', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 3, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'PSG2'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C2)', 'José Antonio Parejo Maestre, Antonio Ruiz Cortes, Irene Bedilia Estrada Torres, Alfonso Eduardo Marquez Chamorro, Alejandro Garcia Fernandez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'PSG2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'PSG2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'PSG2'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T2 (C2)', 'José Antonio Parejo Maestre, Antonio Ruiz Cortes, Alejandro Garcia Fernandez, Alfonso Eduardo Marquez Chamorro'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'PSG2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'PSG2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'PSG2'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T3 (C2)', 'Carlos Guillermo Müller Cejas, Irene Bedilia Estrada Torres, Alejandro Garcia Fernandez, María Dolores Acuña Garrido, Alfonso Eduardo Marquez Chamorro'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'PSG2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'PSG2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('PSM', 'PSM', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 3, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'PSM'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C1)', 'Alberto Olmo Fernandez, Clara Lebrato Vazquez, Javier Maria Mora Merchan'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'PSM'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'PSM'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'PSM'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'PSM'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'PSM'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T2 (C1)', 'Alberto Jesus Molina Cantero, Alejandro Casado Galan, Javier Maria Mora Merchan, Manuel Merino Monge'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'PSM'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'PSM'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'PSM'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'PSM'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'PSM'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'PSM'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T3 (C1)', 'Manuel Merino Monge, Eduardo Hidalgo Fort, Paula Navarro Gonzalez, Javier Maria Mora Merchan, Alejandro Casado Galan'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'PSM'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'PSM'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'PSM'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('AAE', 'AAE', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 4, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'AAE'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C1)', 'Fernando Guerrero Lopez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AAE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AAE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('AII', 'AII', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 4, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'AII'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C1)', 'Vicente Carrillo Montero, Francisco Javier Ortega Rodriguez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AII'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AII'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AII'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T2 (C1)', 'Leticia Morales Trujillo, Francisco Javier Ortega Rodriguez, Vicente Carrillo Montero'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AII'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AII'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AII'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('ASC', 'ASC', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 4, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'ASC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C1)', 'Maria Iluminada Baturone Castillo, Francisco Vidal Fernandez Fernandez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ASC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ASC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ASC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('C', 'C', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 4, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'C'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C1)', 'Felix Gudiel Rodriguez, Victor Alvarez Solano, Jose Andres Armario Sampalo'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'C'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'C'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'C'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T2 (C1)', 'Jose Andres Armario Sampalo, Victor Alvarez Solano, Felix Gudiel Rodriguez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'C'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'C'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('CBD', 'CBD', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 4, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'CBD'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C2)', 'Maria Teresa Gomez Lopez, Octavio Martin Diaz, Antonia Maria Reina Quintero'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'CBD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CBD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CBD'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T2 (C2)', 'Maria Teresa Gomez Lopez, Octavio Martin Diaz, Antonia Maria Reina Quintero'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'CBD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CBD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('DI', 'DI', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 4, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'DI'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C1)', 'Miguel Alvarez Ortega'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'DI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'DI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('EC', 'EC', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 4, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'EC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C2)', 'Maria De Los Remedios Sillero Denamiel'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'EC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('EGC', 'EGC', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 4, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'EGC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C1)', 'Belen Ramos Gutierrez, David Romero Organvidez, Jose Angel Galindo Duarte, Jesus Moreno Leon'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'EGC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EGC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EGC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T2 (C1)', 'David Felipe Benavides Cuevas, David Romero Organvidez, Belen Ramos Gutierrez, Jesus Moreno Leon'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'EGC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EGC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EGC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T3 (C1)', 'Jose Angel Galindo Duarte, Jesus Moreno Leon, David Romero Organvidez, Belen Ramos Gutierrez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'EGC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EGC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('GP', 'GP', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 4, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'GP'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C1)', 'Carmen Baena Sanchez, Ricardo Galan De Vega, Jose Miguel Vives Martinez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'GP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'GP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('ISPP', 'ISPP', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 4, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'ISPP'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C2)', 'Irene Bedilia Estrada Torres'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ISPP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ISPP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ISPP'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T2 (C2)', 'Alberto Martin Lopez, Carlos Guillermo Müller Cejas'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ISPP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ISPP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('MCG', 'MCG', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 4, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'MCG'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C1)', 'Ignacio Eguia Salinas, Jose Carlos Molina Gomez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'MCG'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'MCG'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('OS', 'OS', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 4, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'OS'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C2)', 'Pedro Luis Luque Calvo, Jose Luis Pino Mejias'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'OS'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'OS'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('PGPI', 'PGPI', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 4, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'PGPI'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C1)', 'María Dolores Acuña Garrido, Juan Manuel Cordero Valle, Antonio Martinez Rojas, Maria Jose Escalona Cuaresma, Jesus Torres Valderrama, Jose Gonzalez Enriquez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'PGPI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'PGPI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'PGPI'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T2 (C1)', 'María Dolores Acuña Garrido, Juan Manuel Cordero Valle, Jose Gonzalez Enriquez, Antonio Martinez Rojas, Maria Jose Escalona Cuaresma, Jesus Torres Valderrama'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'PGPI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'PGPI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'PGPI'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T3 (C1)', 'María Dolores Acuña Garrido, Juan Manuel Cordero Valle, Jose Gonzalez Enriquez, Antonio Martinez Rojas, Maria Jose Escalona Cuaresma, Nicolas Sanchez Gomez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'PGPI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'PGPI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('PID', 'PID', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 4, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'PID'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C2)', 'Elena Camacho Aguilar, Maria Jose Jimenez Rodriguez, Belen Medrano Garfia'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'PID'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'PID'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('SSII', 'SSII', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 4, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'SSII'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C2)', 'Rafael Martinez Gasca, Angel Jesus Varela Vaca, Rafael Ceballos Guerrero'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'SSII'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'SSII'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('T', 'T', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 4, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'T'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C2)', 'Alejandro Millan Calderon'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'T'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'T'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'T'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'T'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('TIS', 'TIS', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-s', id, 4, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'TIS'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C1)', 'María Gloria Miro Amarante'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'TIS'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'TIS'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'TIS'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'TIS'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T2 (C1)', 'Juan Ignacio Guerrero Alonso, María Gloria Miro Amarante'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'TIS'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'TIS'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'TIS'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'TIS'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

insert into public.degrees (id, name, abbreviation, center, is_double_degree, sort_order)
values ('giti', 'Grado en Ingeniería Informática - Tecnologías Informáticas', 'GII-TI', 'ETSII', false, 30)
on conflict (id) do update set
  name = excluded.name,
  abbreviation = excluded.abbreviation,
  center = excluded.center,
  is_double_degree = excluded.is_double_degree,
  sort_order = excluded.sort_order;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('AE', 'AE', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 1, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'AE'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C2)', 'Andres Padillo Eguia, Jose Miguel Vives Martinez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AE'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T2 (C2)', 'Jose Carlos Molina Gomez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AE'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T3 (C2)', 'Andres Padillo Eguia, Jose Miguel Vives Martinez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('ALN', 'ALN', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 1, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C2)', 'Manuel Jesus Soto Prieto, Pilar Gomez-caminero Tellez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T2 (C2)', 'Beatriz Silva Gallardo, Pilar Gomez-caminero Tellez, Rafael Robles Arias'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T3 (C2)', 'Manuel Jesus Soto Prieto, Pilar Gomez-caminero Tellez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('CED', 'CED', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 1, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C1)', 'Maria Del Pilar Parra Fernandez, Alejandro Casado Galan, David Guerrero Martos'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T2 (C1)', 'Maria Dolores Hernandez Velazquez, Isabel Maria Gomez Gonzalez, Paula Navarro Gonzalez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T3 (C1)', 'Maria Del Pilar Parra Fernandez, Alejandro Casado Galan, David Guerrero Martos'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('CIN', 'CIN', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 1, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'CIN'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C1)', 'Rosario Arriola Hernandez, Beatriz Silva Gallardo, Alfonso Marquez Martinez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'CIN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CIN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CIN'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T2 (C1)', 'Beatriz Silva Gallardo, Delia Garijo Royo'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'CIN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CIN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CIN'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T3 (C1)', 'Rosario Arriola Hernandez, Beatriz Silva Gallardo, Alfonso Marquez Martinez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'CIN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CIN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('E', 'E', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 1, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'E'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C2)', 'Miguel Angel Pozo Montaño, Jose Carlos Castro Gomez, Alberto Torrejon Valenzuela'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'E'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'E'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'E'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T2 (C2)', 'Maria Teresa Gomez Gomez, Francisco Jose Jacome Maura, Martina Fischetti'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'E'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'E'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'E'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T3 (C2)', 'Miguel Angel Pozo Montaño, Jose Carlos Castro Gomez, Alberto Torrejon Valenzuela'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'E'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'E'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('EdC', 'EdC', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 1, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C2)', 'Maria Del Pilar Parra Fernandez, Maria Dolores Hernandez Velazquez, Samuel Yanes Luis'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T2 (C2)', 'David Guerrero Martos, Samuel Yanes Luis, Isabel Maria Gomez Gonzalez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T3 (C2)', 'Maria Del Pilar Parra Fernandez, Maria Dolores Hernandez Velazquez, Samuel Yanes Luis'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('FFI', 'FFI', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 1, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C1)', 'Jose Luis Mas Balbuena, Niurka Rodriguez Quintero, Triana Czermak Alvarez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T2 (C1)', 'Alejandro Martinez Ros, Jose Luis Mas Balbuena, Niurka Rodriguez Quintero'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T3 (C1)', 'Jose Luis Mas Balbuena, Niurka Rodriguez Quintero, Triana Czermak Alvarez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('FP', 'FP', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 1, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C1)', 'Fermin Cruz Mata, Francisco Jose Galan Morillo, Patricia Jimenez Aguirre, Jose Enrique Sanchez Lopez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C2)', 'Fermin Cruz Mata, Francisco Jose Galan Morillo, Belen Ramos Gutierrez, Cristina Rubio Escudero'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T2 (C1)', 'Jose Mariano Gonzalez Romano, Fernando Enriquez De Salamanca Ros, Pablo Reina Jimenez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T2 (C2)', 'Jose Mariano Gonzalez Romano, María Dolores Acuña Garrido, Daniel Mateos Garcia'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T3 (C1)', 'Fermin Cruz Mata, Francisco Jose Galan Morillo, Patricia Jimenez Aguirre, Jose Enrique Sanchez Lopez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T3 (C2)', 'Fermin Cruz Mata, Francisco Jose Galan Morillo, Belen Ramos Gutierrez, Cristina Rubio Escudero'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('IMD', 'IMD', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 1, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'IMD'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C1)', 'Juan Carlos Dana Jimenez, Luisa Maria Camacho Santana'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'IMD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IMD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IMD'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T2 (C1)', 'Juan Carlos Dana Jimenez, Luisa Maria Camacho Santana'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'IMD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IMD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IMD'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T3 (C1)', 'Juan Carlos Dana Jimenez, Luisa Maria Camacho Santana'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'IMD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IMD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('AC', 'AC', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 2, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C2)', 'Elena Cerezuela Escudero, Antonio Abad Civit Balcells, Maria Lourdes Miro Amarante, Manuel Rivas Perez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T2 (C2)', 'Manuel Jesus Dominguez Morales, Manuel Rivas Perez, Maria Lourdes Miro Amarante, Francisco Luna Perejon, Lourdes Duran Lopez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T3 (C2)', 'Javier Civit Masot, Lourdes Duran Lopez, Elena Cerezuela Escudero'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('ADDA', 'ADDA', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 2, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C1)', 'Irene Barba Rodriguez, Antonio Manuel Gutierrez Fernandez, Diana Borrego Nuñez, Juan Alberto Gallardo Gomez, Javier Jesus Gutierrez Rodriguez, Jose Enrique Sanchez Lopez, Francisco Javier Ferrer Troyano, Francisco Fernando De La Rosa Troyano'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C2)', 'Irene Barba Rodriguez, Antonio Manuel Gutierrez Fernandez, Diana Borrego Nuñez, Juan Alberto Gallardo Gomez, Javier Jesus Gutierrez Rodriguez, Jose Enrique Sanchez Lopez, Francisco Javier Ferrer Troyano, Francisco Fernando De La Rosa Troyano'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T2 (C1)', 'Rafael Ceballos Guerrero, Maria Del Mar Martinez Ballesteros, Irene Barba Rodriguez, Antonio Manuel Gutierrez Fernandez, Diana Borrego Nuñez, Jose Enrique Sanchez Lopez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T2 (C2)', 'Rafael Ceballos Guerrero, Maria Del Mar Martinez Ballesteros, Irene Barba Rodriguez, Antonio Manuel Gutierrez Fernandez, Diana Borrego Nuñez, Jose Enrique Sanchez Lopez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T3 (C1)', 'Antonio Manuel Gutierrez Fernandez, Javier Jesus Gutierrez Rodriguez, Antonio Martinez Rojas, Jose Enrique Sanchez Lopez, Francisco Javier Ferrer Troyano, Adrian Romero Flores'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T3 (C2)', 'Antonio Manuel Gutierrez Fernandez, Javier Jesus Gutierrez Rodriguez, Antonio Martinez Rojas, Jose Enrique Sanchez Lopez, Francisco Javier Ferrer Troyano, Adrian Romero Flores'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ADDA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('AR', 'AR', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 2, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'AR'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C2)', 'Alejandro Casado Galan, Jorge Ropero Rodriguez, Paula Heimberg González, German Cano Quiveu'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AR'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AR'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AR'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AR'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T2 (C2)', 'Enrique Dorronzoro Zubiete, Alejandro Casado Galan'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AR'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AR'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AR'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AR'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AR'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T3 (C2)', 'Julian Viejo Cortes, Clara Lebrato Vazquez, German Cano Quiveu'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AR'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AR'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AR'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('IISSI1', 'IISSI1', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 2, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'IISSI1'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C1)', 'Maria Margarita Cruz Risco, David Ruiz Cortes'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'IISSI1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IISSI1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IISSI1'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T2 (C1)', 'David Ruiz Cortes, Inmaculada Concepcion Hernandez Salmeron, Maria Margarita Cruz Risco'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'IISSI1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IISSI1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IISSI1'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T3 (C1)', 'David Ruiz Cortes, Maria Margarita Cruz Risco'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'IISSI1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IISSI1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('IISSI2', 'IISSI2', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 2, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'IISSI2'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C2)', 'Maria Margarita Cruz Risco, Carlos Arevalo Maldonado, Jose Calderon Valdivia'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'IISSI2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IISSI2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IISSI2'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T2 (C2)', 'Inmaculada Concepcion Hernandez Salmeron, David Ruiz Cortes, Jose Calderon Valdivia, Carlos Arevalo Maldonado'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'IISSI2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IISSI2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IISSI2'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T3 (C2)', 'Carlos Arevalo Maldonado, Daniel Ayala Hernandez, Diego Manuel Galloso Fernandez, Inmaculada Concepcion Hernandez Salmeron, Aitor Rodriguez Dueñas'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'IISSI2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IISSI2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('LI', 'LI', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 2, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'LI'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C1)', 'Andres Cordon Franco'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'LI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'LI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'LI'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T2 (C1)', 'Joaquin Borrego Diaz'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'LI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'LI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'LI'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T3 (C1)', 'Fernando Sancho Caparrini'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'LI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'LI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('MD', 'MD', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 2, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'MD'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C1)', 'Yolanda De La Riva Moreno, Alberto Cerezo Cid'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'MD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'MD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'MD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'MD'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T2 (C1)', 'Yolanda De La Riva Moreno, Alberto Cerezo Cid'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'MD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'MD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'MD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'MD'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T3 (C1)', 'Emmanuel Jean Briand, Alberto Cerezo Cid'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'MD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'MD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('RC', 'RC', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 2, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'RC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C1)', 'Jorge Ropero Rodriguez, Jose Manuel Bravo Garcia, Julian Viejo Cortes, Eduardo Hidalgo Fort, Paula Navarro Gonzalez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'RC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'RC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'RC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'RC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T2 (C1)', 'Alejandro Carrasco Muñoz, Julian Viejo Cortes, Jose Manuel Bravo Garcia, Eduardo Hidalgo Fort, Paula Navarro Gonzalez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'RC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'RC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'RC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'RC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'RC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T3 (C1)', 'Julian Viejo Cortes, Adrian Estrada Perez, Samuel Dominguez Cid'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'RC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'RC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'RC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('SO', 'SO', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 2, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'SO'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C2)', 'David Gutierrez Aviles, Jose Antonio Perez Castellanos'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'SO'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'SO'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'SO'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T2 (C2)', 'David Romero Organvidez, David Gutierrez Aviles'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'SO'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'SO'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'SO'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T3 (C2)', 'Maria Elena Molina Reyes, Leticia Morales Trujillo, David Romero Organvidez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'SO'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'SO'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('AIA', 'AIA', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 3, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'AIA'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C2)', 'Jose Luis Ruiz Reina, Francisco Eduardo Sanchez Karhunen'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AIA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AIA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('ASD', 'ASD', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 3, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'ASD'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C2)', 'Luis Muñoz Saavedra, Jose Luis Sevillano Ramos, Maria Jose Moron Fernandez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ASD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ASD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('CIMSI', 'CIMSI', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 3, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'CIMSI'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C1)', 'Daniel Cascado Caballero'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'CIMSI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CIMSI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('GEE', 'GEE', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 3, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'GEE'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C1)', 'Mario Canivell Rodriguez, Carlos Manuel Gomez Alvarez, Jose Carlos Molina Gomez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'GEE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'GEE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('GSI', 'GSI', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 3, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'GSI'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C1)', 'Joaquin Peña Siles'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'GSI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'GSI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('IA', 'IA', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 3, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'IA'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C1)', 'Maria Carmen Graciani Diaz, Andres Nicolas Uranga Limon'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'IA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IA'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T2 (C1)', 'David Orellana Martin, Andres Nicolas Uranga Limon'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'IA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IA'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T3 (C1)', 'Pedro Almagro Blanco'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'IA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('MASI', 'MASI', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 3, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'MASI'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C2)', 'Maria Cruz Lopez De Los Mozos Martin, Jose Maria Ucha Enriquez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'MASI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'MASI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'MASI'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T2 (C2)', 'Jose Maria Ucha Enriquez, Maria Cruz Lopez De Los Mozos Martin'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'MASI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'MASI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('PD', 'PD', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 3, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'PD'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C1)', 'David Solis Martin, Antonio Ramirez De Arellano Marrero'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'PD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'PD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'PD'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T2 (C1)', 'Eduardo Perez Perdomo, Antonio Ramirez De Arellano Marrero, David Solis Martin'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'PD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'PD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('PL', 'PL', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 3, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'PL'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C1)', 'Francisco Jose Galan Morillo'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'PL'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'PL'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T2 (C1)', 'Manuel Carranza Garcia, Maria Salas Urbano'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'PL'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'PL'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'PL'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('SI', 'SI', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 3, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'SI'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C2)', 'Joaquin Borrego Diaz, Andres Nicolas Uranga Limon'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'SI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'SI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'SI'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T2 (C2)', 'Jesus Giraldez Cru'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'SI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'SI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'SI'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T3 (C2)', 'Victor Ramos Gonzalez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'SI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'SI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('SIE', 'SIE', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 3, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'SIE'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C2)', 'Fernando Enriquez De Salamanca Ros'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'SIE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'SIE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'SIE'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T2 (C2)', 'Fermin Cruz Mata, Fernando Enriquez De Salamanca Ros'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'SIE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'SIE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'SIE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('SOS', 'SOS', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 3, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'SOS'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C2)', 'Pablo Fernandez Montes'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'SOS'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('TAI', 'TAI', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 3, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'TAI'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C1)', 'German Cano Quiveu, Paulino Ruiz De Clavijo Vazquez, Noelia Navarro Moreno'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'TAI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'TAI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'TAI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'TAI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'TAI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('AII', 'AII', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 4, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'AII'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C2)', 'Vicente Carrillo Montero'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AII'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AII'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AII'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('ASC', 'ASC', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 4, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'ASC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C2)', 'Maria Iluminada Baturone Castillo'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ASC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ASC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('ASI', 'ASI', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 4, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'ASI'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C1)', 'Jaime Benjumea Mondejar'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ASI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ASI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ASI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('C', 'C', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 4, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'C'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C2)', 'Victor Alvarez Solano, Felix Gudiel Rodriguez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'C'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'C'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('CM', 'CM', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 4, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'CM'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C2)', 'Rafael Paz Vicente'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'CM'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CM'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CM'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CM'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('EC', 'EC', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 4, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'EC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C2)', 'Maria De Los Remedios Sillero Denamiel'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'EC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('GP', 'GP', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 4, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'GP'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C2)', 'Jose Manuel Garcia Sanchez, Ramon Piedra De La Cuadra'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'GP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'GP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('GPS', 'GPS', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 4, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'GPS'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C1)', 'Cristina Cabanillas Macias, Irene Bedilia Estrada Torres, Adela Del Rio Ortega'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'GPS'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'GPS'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('IE', 'IE', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 4, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'IE'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C2)', 'Francisco Javier Ortega Rodriguez, Aitor Rodriguez Dueñas, Beatriz Pontes Balanza'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'IE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('IPO', 'IPO', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 4, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'IPO'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C1)', 'Victor Jesus Diaz Madrigal, Jose Mariano Gonzalez Romano'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'IPO'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'IPO'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('ISI', 'ISI', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 4, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'ISI'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C1)', 'Enrique Ostua Aranguena'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ISI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ISI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('MARSI', 'MARSI', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 4, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'MARSI'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C2)', 'Francisco Jose Dominguez Mayo, Miguel Angel Olivero Gonzalez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'MARSI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'MARSI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('MATI', 'MATI', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 4, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'MATI'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C1)', 'Maria Nieves Atienza Martinez, Pedro Gomez De Terreros Oramas, Jose Ramon Portillo Fernandez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'MATI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('MC', 'MC', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 4, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'MC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C1)', 'Juan Vicente Gutierrez Santacreu, Maria Cruz Lopez De Los Mozos Martin'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'MC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'MC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('MCC', 'MCC', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 4, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'MCC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C2)', 'Andres Cordon Franco'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'MCC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'MCC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('PGPI', 'PGPI', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 4, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'PGPI'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C1)', 'Victor Alvarez Solano, Jose Andres Armario Sampalo, Felix Gudiel Rodriguez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'PGPI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'PGPI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'PGPI'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T2 (C1)', 'Felix Gudiel Rodriguez, Jose Andres Armario Sampalo'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'PGPI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'PGPI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('PID', 'PID', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 4, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'PID'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C1)', 'Elena Camacho Aguilar, Maria Jose Jimenez Rodriguez, Belen Medrano Garfia'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'PID'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'PID'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('SSII', 'SSII', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 4, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'SSII'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C1)', 'Rafael Ceballos Guerrero'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'SSII'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'SSII'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('T', 'T', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 4, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'T'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C1)', 'Juan Antonio Castro Garcia'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'T'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('TIS', 'TIS', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'giti', id, 4, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'TIS'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T1 (C2)', 'María Gloria Miro Amarante'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'TIS'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'TIS'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'TIS'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

insert into public.degrees (id, name, abbreviation, center, is_double_degree, sort_order)
values ('us-etsii-ia', 'Grado en Ingeniería de Inteligencia Artificial', 'GII-IA', 'ETSII', false, 40)
on conflict (id) do update set
  name = excluded.name,
  abbreviation = excluded.abbreviation,
  center = excluded.center,
  is_double_degree = excluded.is_double_degree,
  sort_order = excluded.sort_order;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('AE', 'AE', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-ia', id, 1, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'AE'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C1)', 'Jesus Racero Moreno, Pablo Soriano Lopez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AE'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T3 (C1)', 'Jesus Racero Moreno, Pablo Soriano Lopez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AE'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C1)', 'Jesus Racero Moreno, Pablo Soriano Lopez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AE'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T3 (C1)', 'Jesus Racero Moreno, Pablo Soriano Lopez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('ALN', 'ALN', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-ia', id, 1, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C2)', 'Rafael Robles Arias, Felix Gudiel Rodriguez, Beatriz Silva Gallardo'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T3 (C2)', 'Rafael Robles Arias, Felix Gudiel Rodriguez, Beatriz Silva Gallardo'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C2)', 'Rafael Robles Arias, Felix Gudiel Rodriguez, Beatriz Silva Gallardo'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T3 (C2)', 'Rafael Robles Arias, Felix Gudiel Rodriguez, Beatriz Silva Gallardo'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ALN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('CED', 'CED', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-ia', id, 1, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C1)', 'Francisco Sivianes Castillo, Maria Del Pilar Parra Fernandez, Daniel Martin Fernandez, Santiago Joaquin Fernandez Scagliusi'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T3 (C1)', 'Francisco Sivianes Castillo, Maria Del Pilar Parra Fernandez, Daniel Martin Fernandez, Santiago Joaquin Fernandez Scagliusi'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C1)', 'Francisco Sivianes Castillo, Maria Del Pilar Parra Fernandez, Daniel Martin Fernandez, Santiago Joaquin Fernandez Scagliusi'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T3 (C1)', 'Francisco Sivianes Castillo, Maria Del Pilar Parra Fernandez, Daniel Martin Fernandez, Santiago Joaquin Fernandez Scagliusi'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CED'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('CIN', 'CIN', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-ia', id, 1, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'CIN'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C1)', 'Rafael Robles Arias, Emmanuel Jean Briand, Yolanda De La Riva Moreno'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'CIN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CIN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CIN'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T3 (C1)', 'Rafael Robles Arias, Emmanuel Jean Briand, Yolanda De La Riva Moreno'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'CIN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CIN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CIN'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C1)', 'Rafael Robles Arias, Emmanuel Jean Briand, Yolanda De La Riva Moreno'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'CIN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CIN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CIN'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T3 (C1)', 'Rafael Robles Arias, Emmanuel Jean Briand, Yolanda De La Riva Moreno'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'CIN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CIN'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('E', 'E', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-ia', id, 1, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'E'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C2)', 'Antonio Rufian Lizana, Isabel Carlota Reymundo Dominguez, Jose Carlos Castro Gomez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'E'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'E'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'E'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T3 (C2)', 'Antonio Rufian Lizana, Isabel Carlota Reymundo Dominguez, Jose Carlos Castro Gomez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'E'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'E'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'E'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C2)', 'Antonio Rufian Lizana, Isabel Carlota Reymundo Dominguez, Jose Carlos Castro Gomez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'E'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'E'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'E'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T3 (C2)', 'Antonio Rufian Lizana, Isabel Carlota Reymundo Dominguez, Jose Carlos Castro Gomez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'E'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'E'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('EdC', 'EdC', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-ia', id, 1, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C2)', 'Sergio Martin Guillen, Maria Del Pilar Parra Fernandez, David Guerrero Martos'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T3 (C2)', 'Sergio Martin Guillen, Maria Del Pilar Parra Fernandez, David Guerrero Martos'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C2)', 'Sergio Martin Guillen, Maria Del Pilar Parra Fernandez, David Guerrero Martos'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T3 (C2)', 'Sergio Martin Guillen, Maria Del Pilar Parra Fernandez, David Guerrero Martos'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EdC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('FFI', 'FFI', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-ia', id, 1, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C2)', 'Faustino Palmero Acebedo, Alejandro Martinez Ros, Gonzalo Plaza Valtueña'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T3 (C2)', 'Faustino Palmero Acebedo, Alejandro Martinez Ros, Gonzalo Plaza Valtueña'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C2)', 'Faustino Palmero Acebedo, Alejandro Martinez Ros, Gonzalo Plaza Valtueña'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T3 (C2)', 'Faustino Palmero Acebedo, Alejandro Martinez Ros, Gonzalo Plaza Valtueña'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FFI'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('FP1', 'FP1', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-ia', id, 1, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'FP1'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C1)', 'Fermin Cruz Mata, Alfonso Maria De Bengoa Diaz'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FP1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP1'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T3 (C1)', 'Fermin Cruz Mata, Alfonso Maria De Bengoa Diaz'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FP1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP1'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C1)', 'Fermin Cruz Mata, Alfonso Maria De Bengoa Diaz'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FP1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP1'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T3 (C1)', 'Fermin Cruz Mata, Alfonso Maria De Bengoa Diaz'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FP1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('FP2', 'FP2', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-ia', id, 1, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'FP2'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C2)', 'Jose Cristobal Riquelme Santos, Alfonso Maria De Bengoa Diaz'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FP2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP2'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T3 (C2)', 'Jose Cristobal Riquelme Santos, Alfonso Maria De Bengoa Diaz'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FP2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP2'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C2)', 'Jose Cristobal Riquelme Santos, Alfonso Maria De Bengoa Diaz'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FP2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP2'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T3 (C2)', 'Jose Cristobal Riquelme Santos, Alfonso Maria De Bengoa Diaz'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FP2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('MD1', 'MD1', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-ia', id, 1, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'MD1'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C1)', 'Maria Magdalena Fernandez Lebron, Amparo Osuna Lucena, Maria Dolores Frau Garcia'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'MD1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'MD1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'MD1'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T3 (C1)', 'Maria Magdalena Fernandez Lebron, Amparo Osuna Lucena, Maria Dolores Frau Garcia'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'MD1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'MD1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'MD1'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C1)', 'Maria Magdalena Fernandez Lebron, Amparo Osuna Lucena, Maria Dolores Frau Garcia'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'MD1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'MD1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'MD1'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T3 (C1)', 'Maria Magdalena Fernandez Lebron, Amparo Osuna Lucena, Maria Dolores Frau Garcia'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'MD1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'MD1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

insert into public.degrees (id, name, abbreviation, center, is_double_degree, sort_order)
values ('us-etsii-sa', 'Grado en Ingeniería de la Salud', 'GIS', 'ETSII', false, 50)
on conflict (id) do update set
  name = excluded.name,
  abbreviation = excluded.abbreviation,
  center = excluded.center,
  is_double_degree = excluded.is_double_degree,
  sort_order = excluded.sort_order;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('AC', 'AC', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-sa', id, 1, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C2)', 'Victor Alvarez Solano, Victor Diaz Gil, Alvaro Dominguez Gutierrez, Maria Teresa Gonzalez Montesino, Maria Cruz Lopez De Los Mozos Martin'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T2 (C2)', 'Alvaro Dominguez Gutierrez, Victor Diaz Gil, Maria Cruz Lopez De Los Mozos Martin'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C2)', 'Victor Alvarez Solano, Victor Diaz Gil, Alvaro Dominguez Gutierrez, Maria Teresa Gonzalez Montesino, Maria Cruz Lopez De Los Mozos Martin'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T2 (C2)', 'Victor Alvarez Solano, Victor Diaz Gil, Alvaro Dominguez Gutierrez, Maria Teresa Gonzalez Montesino, Maria Cruz Lopez De Los Mozos Martin'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T3 (C2)', 'Victor Alvarez Solano, Victor Diaz Gil, Alvaro Dominguez Gutierrez, Maria Teresa Gonzalez Montesino, Maria Cruz Lopez De Los Mozos Martin'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AC'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('AL', 'AL', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-sa', id, 1, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'AL'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C1)', 'Rafael Robles Arias, Jose Maria Ucha Enriquez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AL'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AL'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AL'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T2 (C1)', 'Antonio Jesus Cañete Martin, Jose Maria Ucha Enriquez, Manuel Jesus Soto Prieto'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AL'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AL'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AL'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C1)', 'Rafael Robles Arias, Jose Maria Ucha Enriquez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AL'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AL'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AL'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T2 (C1)', 'Rafael Robles Arias, Jose Maria Ucha Enriquez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AL'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AL'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AL'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T3 (C1)', 'Rafael Robles Arias, Jose Maria Ucha Enriquez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AL'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AL'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('BE', 'BE', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-sa', id, 1, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'BE'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C1)', 'Soledad Lopez Enriquez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'BE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'BE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'BE'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T2 (C1)', 'Soledad Lopez Enriquez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'BE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'BE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'BE'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C1)', 'Soledad Lopez Enriquez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'BE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'BE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'BE'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T2 (C1)', 'Soledad Lopez Enriquez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'BE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'BE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'BE'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T3 (C1)', 'Soledad Lopez Enriquez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'BE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'BE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('C', 'C', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-sa', id, 1, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'C'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C1)', 'Maria Cruz Lopez De Los Mozos Martin, Jose Maria Ucha Enriquez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'C'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'C'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'C'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T2 (C1)', 'Jose Maria Ucha Enriquez, Maria Cruz Lopez De Los Mozos Martin'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'C'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'C'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'C'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C1)', 'Maria Cruz Lopez De Los Mozos Martin, Jose Maria Ucha Enriquez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'C'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'C'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'C'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T2 (C1)', 'Maria Cruz Lopez De Los Mozos Martin, Jose Maria Ucha Enriquez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'C'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'C'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'C'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T3 (C1)', 'Maria Cruz Lopez De Los Mozos Martin, Jose Maria Ucha Enriquez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'C'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'C'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('E', 'E', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-sa', id, 1, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'E'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C2)', 'Francisco Jose Jacome Maura, M Cristina Molero Del Rio'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'E'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'E'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'E'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T2 (C2)', 'Diego Ponce Lopez, Jose Alberto Ruiz Alba, Francisco Jose Jacome Maura'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'E'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'E'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'E'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C2)', 'Francisco Jose Jacome Maura, M Cristina Molero Del Rio'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'E'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'E'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'E'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T2 (C2)', 'Francisco Jose Jacome Maura, M Cristina Molero Del Rio'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'E'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'E'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'E'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T3 (C2)', 'Francisco Jose Jacome Maura, M Cristina Molero Del Rio'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'E'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'E'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('F1', 'F1', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-sa', id, 1, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'F1'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C1)', 'Raul Rodriguez Berral, Alejandro Martinez Ros'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'F1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'F1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'F1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'F1'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T2 (C1)', 'Francisco Luis Mesa Ledesma, Alejandro Martinez Ros, Victor Lopez Flores'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'F1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'F1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'F1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'F1'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C1)', 'Raul Rodriguez Berral, Alejandro Martinez Ros'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'F1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'F1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'F1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'F1'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T2 (C1)', 'Raul Rodriguez Berral, Alejandro Martinez Ros'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'F1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'F1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'F1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'F1'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T3 (C1)', 'Raul Rodriguez Berral, Alejandro Martinez Ros'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'F1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'F1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'F1'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('F2', 'F2', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-sa', id, 1, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'F2'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C2)', 'Antonio Leal Plaza, Juan Francisco Rodriguez Archilla, Rafael Romero Garcia, Ana María Ureba Sanchez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'F2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'F2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'F2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'F2'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T2 (C2)', 'Antonio Leal Plaza, Juan Francisco Rodriguez Archilla, Rafael Romero Garcia, Ana María Ureba Sanchez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'F2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'F2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'F2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'F2'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C2)', 'Antonio Leal Plaza, Juan Francisco Rodriguez Archilla, Rafael Romero Garcia, Ana María Ureba Sanchez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'F2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'F2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'F2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'F2'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T2 (C2)', 'Antonio Leal Plaza, Juan Francisco Rodriguez Archilla, Rafael Romero Garcia, Ana María Ureba Sanchez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'F2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'F2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'F2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'F2'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T3 (C2)', 'Antonio Leal Plaza, Juan Francisco Rodriguez Archilla, Rafael Romero Garcia, Ana María Ureba Sanchez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'F2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'F2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'F2'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('FP', 'FP', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-sa', id, 1, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C1)', 'Fernando Enriquez De Salamanca Ros, Jose Antonio Troyano Jimenez, Belen Vega Marquez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T2 (C1)', 'Fernando Enriquez De Salamanca Ros, Jose Antonio Troyano Jimenez, Belen Vega Marquez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C1)', 'Fernando Enriquez De Salamanca Ros, Jose Antonio Troyano Jimenez, Belen Vega Marquez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T2 (C1)', 'Fernando Enriquez De Salamanca Ros, Jose Antonio Troyano Jimenez, Belen Vega Marquez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T3 (C1)', 'Fernando Enriquez De Salamanca Ros, Jose Antonio Troyano Jimenez, Belen Vega Marquez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'FP'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('GE', 'GE', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-sa', id, 1, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'GE'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C2)', 'Juan D Ganaza Vargas, Francisco Jose Gonzalez Dominguez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'GE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'GE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'GE'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T2 (C2)', 'Juan D Ganaza Vargas, Francisco Jose Gonzalez Dominguez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'GE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'GE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'GE'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C2)', 'Juan D Ganaza Vargas, Francisco Jose Gonzalez Dominguez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'GE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'GE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'GE'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T2 (C2)', 'Juan D Ganaza Vargas, Francisco Jose Gonzalez Dominguez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'GE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'GE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'GE'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T3 (C2)', 'Juan D Ganaza Vargas, Francisco Jose Gonzalez Dominguez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'GE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'GE'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('POO', 'POO', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-sa', id, 1, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'POO'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T1 (C2)', 'Juan Antonio Nepomuceno Chamorro, Elena Enamorado Diaz'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'POO'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'POO'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'POO'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '1T2 (C2)', 'Antonio Martinez Rojas, Elena Enamorado Diaz'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'POO'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'POO'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '1T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'POO'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '3T1 (C2)', 'Juan Antonio Nepomuceno Chamorro, Elena Enamorado Diaz'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'POO'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'POO'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '3T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'POO'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T2 (C2)', 'Juan Antonio Nepomuceno Chamorro, Elena Enamorado Diaz'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'POO'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'POO'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'POO'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '4T3 (C2)', 'Juan Antonio Nepomuceno Chamorro, Elena Enamorado Diaz'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'POO'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'POO'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '4T3 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('ACSO', 'ACSO', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-sa', id, 2, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'ACSO'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C2)', 'Jose Luis Sevillano Ramos, Saturnino Vicente Diaz'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ACSO'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ACSO'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ACSO'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T2 (C2)', 'Jose Luis Sevillano Ramos, Saturnino Vicente Diaz'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'ACSO'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'ACSO'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('AF', 'AF', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-sa', id, 2, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'AF'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C2)', 'Jordi Muntane Relat, Laura Romero Perez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AF'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AF'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AF'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AF'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T2 (C2)', 'Jordi Muntane Relat, Laura Romero Perez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AF'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AF'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('AM', 'AM', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-sa', id, 2, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'AM'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C1)', 'Miguel Navarro Castro, Isabel Carlota Reymundo Dominguez, Victor Alvarez Solano, Alfonso Marquez Martinez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AM'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AM'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AM'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T2 (C1)', 'Miguel Navarro Castro, Isabel Carlota Reymundo Dominguez, Socrates Cuadri Crespo, Alfonso Marquez Martinez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'AM'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'AM'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('BCG', 'BCG', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-sa', id, 2, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'BCG'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C2)', 'Maikel Castellano Pozo, Valentine Rosine Comaills, Maria Paula Daza Navarro'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'BCG'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'BCG'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'BCG'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T2 (C2)', 'Maikel Castellano Pozo, Valentine Rosine Comaills, Maria Paula Daza Navarro'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'BCG'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'BCG'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('BD', 'BD', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-sa', id, 2, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'BD'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C2)', 'Beatriz Bernardez Jimenez, Maria Margarita Cruz Risco, Aitor Rodriguez Dueñas'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'BD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'BD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'BD'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T2 (C2)', 'Beatriz Bernardez Jimenez, Maria Margarita Cruz Risco, Aitor Rodriguez Dueñas'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'BD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'BD'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('BMB', 'BMB', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-sa', id, 2, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'BMB'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C1)', 'Gonzalo Alba Jimenez, Lorena Garcia Bernardo, Maria Dolores Navarro Hortal, Inmaculada Pino Perez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'BMB'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'BMB'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'BMB'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'BMB'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T2 (C1)', 'Gonzalo Alba Jimenez, Julia Garcia De La Vega Arenas, Inmaculada Pino Perez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'BMB'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'BMB'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '19:40'::time, '21:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'BMB'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 4, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('CA', 'CA', 6, 2)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-sa', id, 2, 'C2', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'CA'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C2)', 'Diego Francisco Larios Marin, Joaquin Luque Rodriguez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'CA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CA'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T2 (C2)', 'Diego Francisco Larios Marin, Joaquin Luque Rodriguez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'CA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '12:40'::time, '14:30'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C2)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('CME', 'CME', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-sa', id, 2, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'CME'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C1)', 'Servando Carlos Espejo Meana, Diego Vazquez Garcia De La Vega'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'CME'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CME'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CME'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T2 (C1)', 'Servando Carlos Espejo Meana, Diego Vazquez Garcia De La Vega'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'CME'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'CME'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('EDA', 'EDA', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-sa', id, 2, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'EDA'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C1)', 'Carmelo Del Valle Sevillano, Rafael Ceballos Guerrero, Belen Ramos Gutierrez'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'EDA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EDA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EDA'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T2 (C1)', 'Carmelo Del Valle Sevillano, Francisco Javier Ferrer Troyano, Jose Manuel Sanchez Ruiz'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'EDA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 2, '15:30'::time, '17:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EDA'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 5, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values ('EL', 'EL', 6, 1)
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select 'us-etsii-sa', id, 2, 'C1', 'obligatoria', null
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;

with selected_subject as (
  select id from public.subjects where code = 'EL'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T1 (C1)', 'Servando Carlos Espejo Meana, Diego Vazquez Garcia De La Vega, Alberto Yufera Garcia'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'EL'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '10:40'::time, '12:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EL'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T1 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '08:30'::time, '10:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EL'
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, '2T2 (C1)', 'Servando Carlos Espejo Meana, Diego Vazquez Garcia De La Vega, Alberto Yufera Garcia, Antonio Algarin Perez, Santiago Joaquin Fernandez Scagliusi'
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);

with selected_subject as (
  select id from public.subjects where code = 'EL'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 1, '17:40'::time, '19:40'::time, 'theory'
from selected_group;

with selected_subject as (
  select id from public.subjects where code = 'EL'
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = '2T2 (C1)'
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, 3, '15:30'::time, '17:40'::time, 'theory'
from selected_group;
commit;


-- 3. Limpieza defensiva por si habia datos antiguos

-- Limpia asignaturas falsas creadas por combinaciones de horario tipo "FFI / CED".
-- Las asignaturas reales individuales se conservan.

begin;

with bad_subjects as (
  select id
  from public.subjects
  where code like '% / %'
     or name like '% / %'
),
deleted_relations as (
  delete from public.degree_subjects ds
  using bad_subjects bs
  where ds.subject_id = bs.id
  returning ds.subject_id
)
delete from public.subjects s
using bad_subjects bs
where s.id = bs.id
  and not exists (
    select 1
    from public.degree_subjects ds
    where ds.subject_id = s.id
  );

commit;

