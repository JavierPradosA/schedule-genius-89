import fs from 'node:fs';
import { JSDOM } from 'jsdom';

const INPUT = 'tmp_universidad_sevilla_extracted.json';
const OUTPUT = 'src/data/demoData.ts';
const SUBJECT_DETAILS_CACHE = 'tmp_us_subject_details_cache.json';

const subjectDetailsCache = fs.existsSync(SUBJECT_DETAILS_CACHE)
  ? JSON.parse(fs.readFileSync(SUBJECT_DETAILS_CACHE, 'utf8'))
  : {};

function saveSubjectDetailsCache() {
  fs.writeFileSync(SUBJECT_DETAILS_CACHE, JSON.stringify(subjectDetailsCache, null, 2), 'utf8');
}

function normalizeId(value) {
  return value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');
}

function q(value) {
  return JSON.stringify(value);
}

function typeFromOfficial(value) {
  const normalized = value.toLowerCase();
  return normalized.includes('optativa') ? 'optativa' : 'obligatoria';
}

async function fetchDom(url) {
  const response = await fetch(url, {
    headers: {
      'user-agent': 'Mozilla/5.0 OptimaUS data extractor',
    },
  });
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`);
  }
  return new JSDOM(await response.text(), { url });
}

async function scrapeOfficialDegreePlan(degree) {
  if (!degree.sourceUrl) return [];

  try {
    const dom = await fetchDom(degree.sourceUrl);
    const { document } = dom.window;
    const headers = ['Curso', 'Código Asig.', 'Asignatura', 'Créditos', 'Tipo'];
    const table = [...document.querySelectorAll('table')].find((candidate) => {
      const text = candidate.textContent.replace(/\s+/g, ' ');
      return headers.every((header) => text.includes(header));
    });

    if (!table) return [];

    const rows = [...table.querySelectorAll('tr')];
    return rows.flatMap((row) => {
      const rawCells = [...row.querySelectorAll('td')];
      const cells = rawCells.map((cell) => cell.textContent.trim().replace(/\s+/g, ' '));
      if (cells.length < 5 || !/^\d+$/.test(cells[0])) return [];
      const subjectLink = rawCells[2]?.querySelector('a[href]');
      return [{
        course: Number(cells[0]),
        code: cells[1],
        name: cells[2],
        credits: Number(cells[3].replace(',', '.')) || 0,
        officialType: cells[4],
        sourceUrl: subjectLink ? new URL(subjectLink.getAttribute('href'), degree.sourceUrl).href : '',
      }];
    });
  } catch (error) {
    console.warn(`No se pudo extraer plan de ${degree.name}: ${error.message}`);
    return [];
  }
}

function normalizeSubject(raw) {
  return {
    id: normalizeId(raw.code || raw.name),
    name: raw.name,
    code: raw.code || normalizeId(raw.name),
    credits: raw.credits || 6,
    course: raw.course || 1,
    semester: raw.semester || 'A',
    type: typeFromOfficial(raw.officialType || ''),
    groups: raw.groups || [],
    sourceUrl: raw.sourceUrl || '',
  };
}

function parseSemester(duration) {
  const normalized = duration.toLowerCase();
  if (normalized.includes('segundo')) return 'C2';
  if (normalized.includes('primer')) return 'C1';
  return 'A';
}

async function scrapeSubjectDetails(subject) {
  if (!subject.sourceUrl) return subject;
  if (subjectDetailsCache[subject.sourceUrl]) {
    return { ...subject, ...subjectDetailsCache[subject.sourceUrl] };
  }

  try {
    const dom = await fetchDom(subject.sourceUrl);
    const { document } = dom.window;
    const allText = document.body.textContent;
    const duration = [...document.querySelectorAll('tr')]
      .map((row) => [...row.querySelectorAll('th,td')].map((cell) => cell.textContent.trim().replace(/\s+/g, ' ')))
      .find((cells) => cells[0] === 'Duración')?.[1] ?? '';

    const professorSection = allText.split('Profesores').pop()?.split('PROGRAMAS Y PROYECTOS')[0] ?? '';
    const professors = professorSection
      .split('\n')
      .map((line) => line.trim().replace(/\s+/g, ' '))
      .filter((line) => line && line === line.toUpperCase() && /[A-ZÁÉÍÓÚÑ]/.test(line))
      .filter((line) => !['DATOS DE LA ASIGNATURA', 'PROFESORES'].includes(line))
      .filter((line, index, arr) => arr.indexOf(line) === index);

    const semester = parseSemester(duration);
    const groups = professors.length > 0
      ? [{
          id: `${subject.id}-official`,
          name: 'Profesorado oficial',
          professor: professors.join(', '),
          professors,
          type: 'theory',
          sessions: [],
        }]
      : subject.groups;

    const details = { semester, groups };
    subjectDetailsCache[subject.sourceUrl] = details;
    return { ...subject, ...details };
  } catch (error) {
    console.warn(`No se pudo enriquecer ${subject.name}: ${error.message}`);
    if (!String(error.message).includes('fetch failed')) {
      subjectDetailsCache[subject.sourceUrl] = {
        semester: subject.semester,
        groups: subject.groups,
      };
    }
    return subject;
  }
}

function renderSubjects(subjects) {
  const lines = [];

  for (const subject of subjects) {
    lines.push('    {');
    lines.push(`      id: ${q(subject.id)}, name: ${q(subject.name)}, code: ${q(subject.code)}, credits: ${subject.credits},`);
    lines.push(`      course: ${subject.course}, semester: ${q(subject.semester)}, type: ${q(subject.type)},`);
    lines.push('      groups: [');

    for (const group of subject.groups ?? []) {
      const professors = group.professors?.length
        ? group.professors
        : String(group.professor ?? '')
          .split(',')
          .map((name) => name.trim())
          .filter(Boolean);

      lines.push('        {');
      lines.push(`          id: ${q(group.id)}, name: ${q(group.name)}, professor: ${q(group.professor)}, professors: ${q(professors)}, type: ${q(group.type)},`);
      lines.push(
        `          sessions: [${(group.sessions ?? [])
          .map((session) => `{ day: ${session.day} as const, startHour: ${session.startHour}, endHour: ${session.endHour} }`)
          .join(', ')}],`,
      );
      lines.push('        },');
    }

    lines.push('      ],');
    lines.push('    },');
  }

  return lines;
}

function mergePlannedSubjects(planned, scheduled) {
  const scheduledByCode = new Map((scheduled ?? []).map((subject) => [subject.code, subject]));
  const scheduledByName = new Map((scheduled ?? []).map((subject) => [subject.name.toLowerCase(), subject]));

  return planned.map((subject) => {
    const match = scheduledByCode.get(subject.code) ?? scheduledByName.get(subject.name.toLowerCase());
    return match ? { ...subject, ...match, name: subject.name, code: subject.code, credits: subject.credits, course: subject.course } : subject;
  });
}

const extracted = JSON.parse(fs.readFileSync(INPUT, 'utf8'));
const subjectsByDegree = {};

async function mapLimit(items, limit, mapper) {
  const results = new Array(items.length);
  let nextIndex = 0;

  async function worker() {
    while (nextIndex < items.length) {
      const currentIndex = nextIndex++;
      results[currentIndex] = await mapper(items[currentIndex], currentIndex);
    }
  }

  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, worker));
  return results;
}

for (const degree of extracted.degrees) {
  console.log(`Extrayendo plan oficial: ${degree.name}`);
  const plannedBase = (await scrapeOfficialDegreePlan(degree)).map(normalizeSubject);
  const planned = await mapLimit(plannedBase, 12, (subject) => scrapeSubjectDetails(subject));
  saveSubjectDetailsCache();
  const scheduled = extracted.subjectsByDegree?.[degree.id] ?? [];
  subjectsByDegree[degree.id] = planned.length > 0 ? mergePlannedSubjects(planned, scheduled) : scheduled;
}

const legacyGiti = subjectsByDegree.giti;
const degreeLines = extracted.degrees.map((degree) => `  { id: ${q(degree.id)}, name: ${q(degree.name)} },`);

const lines = [];
lines.push('export interface Subject {');
lines.push('  id: string;');
lines.push('  name: string;');
lines.push('  code: string;');
lines.push('  credits: number;');
lines.push('  course: number;');
lines.push("  semester: 'C1' | 'C2' | 'A';");
lines.push("  type: 'obligatoria' | 'optativa';");
lines.push('  mention?: string;');
lines.push('  groups: SubjectGroup[];');
lines.push('}');
lines.push('');
lines.push('export interface SubjectGroup {');
lines.push('  id: string;');
lines.push('  name: string;');
lines.push('  professor: string;');
lines.push('  professors?: string[];');
lines.push("  type: 'theory' | 'lab';");
lines.push('  sessions: Session[];');
lines.push('}');
lines.push('');
lines.push('export interface Session {');
lines.push('  day: 0 | 1 | 2 | 3 | 4;');
lines.push('  startHour: number;');
lines.push('  endHour: number;');
lines.push('}');
lines.push('');
lines.push('export interface TimeBlock {');
lines.push('  day: 0 | 1 | 2 | 3 | 4;');
lines.push('  startHour: number;');
lines.push('  endHour: number;');
lines.push('}');
lines.push('');
lines.push("export const DAYS = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'] as const;");
lines.push('');
lines.push('export const TIME_BLOCKS = [');
lines.push("  { start: 8, end: 10, label: '8:30 - 10:20' },");
lines.push("  { start: 10, end: 12, label: '10:40 - 12:30' },");
lines.push("  { start: 12, end: 14, label: '12:40 - 14:30' },");
lines.push("  { start: 15, end: 17, label: '15:30 - 17:20' },");
lines.push("  { start: 17, end: 19, label: '17:40 - 19:30' },");
lines.push("  { start: 19, end: 21, label: '19:40 - 21:30' },");
lines.push('] as const;');
lines.push('');
lines.push('export const HOURS = TIME_BLOCKS.map(b => b.start);');
lines.push('');
lines.push('export const DEGREES = [');
lines.push(...degreeLines);
lines.push('];');
lines.push('');
lines.push('export const MENTIONS = [');
lines.push("  { id: 'si', name: 'Sistemas de Información' },");
lines.push("  { id: 'ti', name: 'Tecnologías de la Información' },");
lines.push("  { id: 'comp', name: 'Computación' },");
lines.push('];');
lines.push('');
lines.push('const COLORS = [');
[
  'hsl(217 45% 20%)',
  'hsl(42 50% 54%)',
  'hsl(213 35% 35%)',
  'hsl(160 40% 40%)',
  'hsl(340 45% 50%)',
  'hsl(270 35% 45%)',
  'hsl(25 55% 50%)',
  'hsl(190 50% 40%)',
  'hsl(5 50% 45%)',
  'hsl(130 35% 35%)',
].forEach((color) => lines.push(`  ${q(color)},`));
lines.push('];');
lines.push('');
lines.push('export function getSubjectColor(index: number): string {');
lines.push('  return COLORS[index % COLORS.length];');
lines.push('}');
lines.push('');
lines.push('// Datos extraídos de páginas oficiales de la Universidad de Sevilla. Las asignaturas salen de la oferta oficial de grados; horarios/profesorado se rellenan por adaptadores de centro cuando existe fuente pública estructurada.');
lines.push('export const SUBJECTS: Record<string, Subject[]> = {');

for (const degree of extracted.degrees) {
  lines.push(`  ${q(degree.id)}: [`);
  lines.push(...renderSubjects(subjectsByDegree[degree.id] ?? []));
  lines.push('  ],');
}

if (legacyGiti && !subjectsByDegree['giti']) {
  lines.push('  giti: [');
  lines.push(...renderSubjects(legacyGiti));
  lines.push('  ],');
}

lines.push('};');
lines.push('');

fs.writeFileSync(OUTPUT, lines.join('\n'), 'utf8');
console.log(`Escritos ${Object.keys(subjectsByDegree).length} grados en ${OUTPUT}`);
