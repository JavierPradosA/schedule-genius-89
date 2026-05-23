import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { createRequire } from 'node:module';
import ts from 'typescript';
import pg from 'pg';

const { Client } = pg;
const require = createRequire(import.meta.url);

const ROOT = process.cwd();
const DATABASE_URL = process.env.DATABASE_URL;
const DRY_RUN = process.argv.includes('--dry-run');
const SQL_ARG_INDEX = process.argv.indexOf('--sql');
const SQL_OUTPUT = SQL_ARG_INDEX >= 0 ? process.argv[SQL_ARG_INDEX + 1] : null;

const ETSII_DEGREES = [
  { id: 'us-etsii-c', abbreviation: 'GII-C', sortOrder: 10 },
  { id: 'us-etsii-s', abbreviation: 'GII-S', sortOrder: 20 },
  { id: 'giti', abbreviation: 'GII-TI', sortOrder: 30 },
  { id: 'us-etsii-ia', abbreviation: 'GII-IA', sortOrder: 40 },
  { id: 'us-etsii-sa', abbreviation: 'GIS', sortOrder: 50 },
];

const COMBINED_SUBJECT_PATTERN = /\s\/\s/;

function isOfficialSubject(subject) {
  return !COMBINED_SUBJECT_PATTERN.test(subject.name) && !COMBINED_SUBJECT_PATTERN.test(subject.code);
}

function loadDemoData() {
  const demoPath = path.join(ROOT, 'src', 'data', 'demoData.ts');
  const source = fs.readFileSync(demoPath, 'utf8');
  const compiled = ts.transpileModule(source, {
    compilerOptions: {
      module: ts.ModuleKind.CommonJS,
      target: ts.ScriptTarget.ES2020,
      esModuleInterop: true,
    },
  }).outputText;

  const module = { exports: {} };
  const sandbox = {
    exports: module.exports,
    module,
    require,
  };

  vm.runInNewContext(compiled, sandbox, { filename: demoPath });
  return sandbox.module.exports;
}

function blockHourToTime(hour) {
  const map = {
    8: '08:30',
    10: '10:40',
    12: '12:40',
    14: '14:30',
    15: '15:30',
    17: '17:40',
    19: '19:40',
    21: '21:30',
  };
  return map[hour] ?? `${String(Math.floor(hour)).padStart(2, '0')}:00`;
}

function sqlString(value) {
  if (value === null || value === undefined || value === '') return 'null';
  return `'${String(value).replaceAll("'", "''")}'`;
}

function sqlNumber(value) {
  if (value === null || value === undefined || Number.isNaN(Number(value))) return 'null';
  return String(Number(value));
}

function exportSql(DEGREES, SUBJECTS, outputPath) {
  const statements = [
    '-- Seed ETSII generado desde src/data/demoData.ts',
    '-- Ejecuta primero supabase/academic_etsii.sql',
    'begin;',
  ];

  for (const degreeSeed of ETSII_DEGREES) {
    const degree = DEGREES.find((item) => item.id === degreeSeed.id);
    if (!degree) continue;

    statements.push(`
insert into public.degrees (id, name, abbreviation, center, is_double_degree, sort_order)
values (${sqlString(degree.id)}, ${sqlString(degree.name)}, ${sqlString(degreeSeed.abbreviation)}, 'ETSII', false, ${degreeSeed.sortOrder})
on conflict (id) do update set
  name = excluded.name,
  abbreviation = excluded.abbreviation,
  center = excluded.center,
  is_double_degree = excluded.is_double_degree,
  sort_order = excluded.sort_order;`);

    for (const subject of (SUBJECTS[degree.id] ?? []).filter(isOfficialSubject)) {
      const subjectSemester = subject.semester === 'A' ? null : Number(subject.semester.replace('C', ''));

      statements.push(`
with upsert_subject as (
  insert into public.subjects (code, name, credits, semester)
  values (${sqlString(subject.code)}, ${sqlString(subject.name)}, ${sqlNumber(subject.credits)}, ${sqlNumber(subjectSemester)})
  on conflict (code) do update set
    name = excluded.name,
    credits = excluded.credits,
    semester = excluded.semester
  returning id
)
insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
select ${sqlString(degree.id)}, id, ${sqlNumber(subject.course)}, ${sqlString(subject.semester)}, ${sqlString(subject.type)}, ${sqlString(subject.mention)}
from upsert_subject
on conflict (degree_id, subject_id) do update set
  course = excluded.course,
  semester = excluded.semester,
  type = excluded.type,
  mention = excluded.mention;`);

      for (const group of subject.groups ?? []) {
        statements.push(`
with selected_subject as (
  select id from public.subjects where code = ${sqlString(subject.code)}
),
upsert_group as (
  insert into public.subject_groups (subject_id, group_name, professor)
  select id, ${sqlString(group.name)}, ${sqlString(group.professor)}
  from selected_subject
  on conflict (subject_id, group_name) do update set
    professor = excluded.professor
  returning id
)
delete from public.group_meetings
where group_id in (select id from upsert_group);`);

        for (const session of group.sessions ?? []) {
          statements.push(`
with selected_subject as (
  select id from public.subjects where code = ${sqlString(subject.code)}
),
selected_group as (
  select sg.id
  from public.subject_groups sg
  join selected_subject s on s.id = sg.subject_id
  where sg.group_name = ${sqlString(group.name)}
)
insert into public.group_meetings (group_id, weekday, start_time, end_time, meeting_type)
select id, ${session.day + 1}, ${sqlString(blockHourToTime(session.startHour))}::time, ${sqlString(blockHourToTime(session.endHour))}::time, ${sqlString(group.type)}
from selected_group;`);
        }
      }
    }
  }

  statements.push('commit;');
  fs.writeFileSync(path.resolve(ROOT, outputPath), `${statements.join('\n')}\n`, 'utf8');
}

async function main() {
  const { DEGREES, SUBJECTS } = loadDemoData();

  if (SQL_OUTPUT) {
    exportSql(DEGREES, SUBJECTS, SQL_OUTPUT);
    console.log(`SQL generado: ${SQL_OUTPUT}`);
    return;
  }

  if (DRY_RUN) {
    const summary = ETSII_DEGREES.map((degreeSeed) => {
      const degree = DEGREES.find((item) => item.id === degreeSeed.id);
      return {
        id: degreeSeed.id,
        name: degree?.name ?? 'No encontrado',
      subjects: (SUBJECTS[degreeSeed.id] ?? []).filter(isOfficialSubject).length,
      };
    });

    console.table(summary);
    return;
  }

  if (!DATABASE_URL) {
    throw new Error('Falta DATABASE_URL. Ejemplo: set DATABASE_URL=postgresql://usuario:password@host:5432/optimaus');
  }

  const client = new Client({
    connectionString: DATABASE_URL,
    ssl: process.env.PGSSL === 'disable' ? false : { rejectUnauthorized: false },
  });
  await client.connect();

  let subjectCount = 0;
  let groupCount = 0;
  let meetingCount = 0;

  try {
    await client.query('begin');

    for (const degreeSeed of ETSII_DEGREES) {
      const degree = DEGREES.find((item) => item.id === degreeSeed.id);
      if (!degree) continue;

      await client.query(
        `
        insert into public.degrees (id, name, abbreviation, center, is_double_degree, sort_order)
        values ($1, $2, $3, 'ETSII', false, $4)
        on conflict (id) do update set
          name = excluded.name,
          abbreviation = excluded.abbreviation,
          center = excluded.center,
          is_double_degree = excluded.is_double_degree,
          sort_order = excluded.sort_order
        `,
        [degree.id, degree.name, degreeSeed.abbreviation, degreeSeed.sortOrder],
      );

      for (const subject of (SUBJECTS[degree.id] ?? []).filter(isOfficialSubject)) {
        const subjectResult = await client.query(
          `
          insert into public.subjects (code, name, credits, semester)
          values ($1, $2, $3, $4)
          on conflict (code) do update set
            name = excluded.name,
            credits = excluded.credits,
            semester = excluded.semester
          returning id
          `,
          [
            subject.code,
            subject.name,
            subject.credits,
            subject.semester === 'A' ? null : Number(subject.semester.replace('C', '')),
          ],
        );

        const subjectId = subjectResult.rows[0].id;
        subjectCount += 1;

        await client.query(
          `
          insert into public.degree_subjects (degree_id, subject_id, course, semester, type, mention)
          values ($1, $2, $3, $4, $5, $6)
          on conflict (degree_id, subject_id) do update set
            course = excluded.course,
            semester = excluded.semester,
            type = excluded.type,
            mention = excluded.mention
          `,
          [degree.id, subjectId, subject.course, subject.semester, subject.type, subject.mention ?? null],
        );

        for (const group of subject.groups ?? []) {
          const groupResult = await client.query(
            `
            insert into public.subject_groups (subject_id, group_name, professor)
            values ($1, $2, $3)
            on conflict (subject_id, group_name) do update set
              professor = excluded.professor
            returning id
            `,
            [subjectId, group.name, group.professor],
          );

          const groupId = groupResult.rows[0].id;
          groupCount += 1;

          await client.query('delete from public.group_meetings where group_id = $1', [groupId]);

          for (const session of group.sessions ?? []) {
            await client.query(
              `
              insert into public.group_meetings
                (group_id, weekday, start_time, end_time, meeting_type)
              values ($1, $2, $3::time, $4::time, $5)
              `,
              [
                groupId,
                session.day + 1,
                blockHourToTime(session.startHour),
                blockHourToTime(session.endHour),
                group.type,
              ],
            );
            meetingCount += 1;
          }
        }
      }
    }

    await client.query('commit');
  } catch (error) {
    await client.query('rollback');
    throw error;
  } finally {
    await client.end();
  }

  console.log(`Grados ETSII cargados: ${ETSII_DEGREES.length}`);
  console.log(`Asignaturas relacionadas: ${subjectCount}`);
  console.log(`Grupos cargados: ${groupCount}`);
  console.log(`Franjas horarias cargadas: ${meetingCount}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
