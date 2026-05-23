import fs from 'node:fs';

const data = JSON.parse(fs.readFileSync('tmp_etsii_ti_extracted.json', 'utf8'));
const subjects = data.subjects;
const q = (value) => JSON.stringify(value);

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
lines.push("  { id: 'giti', name: 'Grado en Ingeniería Informática - Tecnologías Informáticas' },");
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
lines.push('// Datos oficiales extraídos de la web de horarios ETSII y del plan de estudios US para el curso 2025-26.');
lines.push('export const SUBJECTS: Record<string, Subject[]> = {');
lines.push('  giti: [');

for (const subject of subjects) {
  lines.push('    {');
  lines.push(`      id: ${q(subject.id)}, name: ${q(subject.name)}, code: ${q(subject.code)}, credits: ${subject.credits},`);
  lines.push(`      course: ${subject.course}, semester: ${q(subject.semester)}, type: ${q(subject.type)},`);
  lines.push('      groups: [');

  for (const group of subject.groups) {
    const professors = group.professor
      .split(',')
      .map((name) => name.trim())
      .filter(Boolean);

    lines.push('        {');
    lines.push(`          id: ${q(group.id)}, name: ${q(group.name)}, professor: ${q(group.professor)}, professors: ${q(professors)}, type: ${q(group.type)},`);
    lines.push(
      `          sessions: [${group.sessions
        .map((session) => `{ day: ${session.day} as const, startHour: ${session.startHour}, endHour: ${session.endHour} }`)
        .join(', ')}],`,
    );
    lines.push('        },');
  }

  lines.push('      ],');
  lines.push('    },');
}

lines.push('  ],');
lines.push('};');
lines.push('');

fs.writeFileSync('src/data/demoData.ts', lines.join('\n'), 'utf8');
console.log(`Escritas ${subjects.length} asignaturas en src/data/demoData.ts`);
