create table if not exists public.feedback_final (
  id_feedback uuid primary key default gen_random_uuid(),
  id_sesion uuid not null,
  facilidad_uso integer not null check (facilidad_uso between 1 and 5),
  utilidad_percibida integer not null check (utilidad_percibida between 1 and 5),
  recomendacion integer not null check (recomendacion between 1 and 5),
  fecha_envio timestamptz not null default now()
);

alter table public.feedback_final enable row level security;

drop policy if exists "Permitir insertar feedback anonimo" on public.feedback_final;

create policy "Permitir insertar feedback anonimo"
on public.feedback_final
for insert
to anon
with check (
  facilidad_uso between 1 and 5
  and utilidad_percibida between 1 and 5
  and recomendacion between 1 and 5
);

grant insert on public.feedback_final to anon;
