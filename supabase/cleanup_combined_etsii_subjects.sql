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
