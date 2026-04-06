export interface Subject {
  id: string;
  name: string;
  code: string;
  credits: number;
  course: number;
  semester: 'C1' | 'C2' | 'A';
  type: 'obligatoria' | 'optativa';
  mention?: string;
  groups: SubjectGroup[];
}

export interface SubjectGroup {
  id: string;
  name: string;
  professor: string;
  type: 'theory' | 'lab';
  sessions: Session[];
}

export interface Session {
  day: 0 | 1 | 2 | 3 | 4; // Mon-Fri
  startHour: number;
  endHour: number;
}

export interface TimeBlock {
  day: 0 | 1 | 2 | 3 | 4;
  startHour: number;
  endHour: number;
}

export const DAYS = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'] as const;

// Time blocks matching the university schedule
export const TIME_BLOCKS = [
  { start: 8, end: 10, label: '8:30 - 10:20' },
  { start: 10, end: 12, label: '10:40 - 12:30' },
  { start: 12, end: 14, label: '12:40 - 14:30' },
  { start: 15, end: 17, label: '15:30 - 17:20' },
  { start: 17, end: 19, label: '17:40 - 19:30' },
  { start: 19, end: 21, label: '19:40 - 21:30' },
] as const;

export const HOURS = TIME_BLOCKS.map(b => b.start);

export const DEGREES = [
  { id: 'giti', name: 'Grado en Ingeniería Informática – Tecnologías Informáticas' },
];

export const MENTIONS = [
  { id: 'si', name: 'Sistemas de Información' },
  { id: 'ti', name: 'Tecnología de la Información' },
  { id: 'comp', name: 'Computación' },
];

const COLORS = [
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
];

export function getSubjectColor(index: number): string {
  return COLORS[index % COLORS.length];
}

type D = 0 | 1 | 2 | 3 | 4;
function s(day: D, startHour: number, endHour: number): Session {
  return { day, startHour, endHour };
}

// Helper to build groups from turn-based schedule data
function buildGroups(
  id: string,
  turns: { name: string; sessions: Session[] }[],
): SubjectGroup[] {
  return turns.map((t, i) => ({
    id: `${id}-${t.name.toLowerCase().replace(/\s/g, '')}`,
    name: t.name,
    professor: '',
    type: 'theory' as const,
    sessions: t.sessions,
  }));
}

// ================================================
// REAL SCHEDULE DATA FROM PDF 2025-26
// Sessions are 2h blocks: 8-10, 10-12, 12-14, 15-17, 17-19, 19-21
// ================================================

export const SUBJECTS: Record<string, Subject[]> = {
  giti: [
    // ============ CURSO 1 - C1 ============
    {
      id: 'ffi', name: 'Fundamentos Físicos de la Informática', code: '2060009', credits: 6,
      course: 1, semester: 'C1', type: 'obligatoria',
      groups: buildGroups('ffi', [
        { name: 'Turno 1', sessions: [s(0,8,10), s(1,10,12), s(3,12,14), s(0,12,14)] },
        { name: 'Turno 2', sessions: [s(2,8,10), s(4,10,12), s(1,12,14), s(2,12,14)] },
        { name: 'Turno 3', sessions: [s(4,15,17), s(1,17,19), s(0,19,21)] },
      ]),
    },
    {
      id: 'imd', name: 'Introducción a la Matemática Discreta', code: '2060005', credits: 6,
      course: 1, semester: 'C1', type: 'obligatoria',
      groups: buildGroups('imd', [
        { name: 'Turno 1', sessions: [s(1,8,10), s(3,10,12), s(4,10,12)] },
        { name: 'Turno 2', sessions: [s(3,8,10), s(1,10,12)] },
        { name: 'Turno 3', sessions: [s(1,15,17), s(3,17,19)] },
      ]),
    },
    {
      id: 'ced', name: 'Circuitos Electrónicos Digitales', code: '2060004', credits: 6,
      course: 1, semester: 'C1', type: 'obligatoria',
      groups: buildGroups('ced', [
        { name: 'Turno 1', sessions: [s(2,8,10), s(4,8,10), s(2,12,14), s(4,12,14)] },
        { name: 'Turno 2', sessions: [s(4,8,10), s(0,10,12), s(4,12,14)] },
        { name: 'Turno 3', sessions: [s(2,15,17), s(0,17,19), s(2,19,21), s(3,19,21)] },
      ]),
    },
    {
      id: 'cin', name: 'Cálculo Infinitesimal y Numérico', code: '2060003', credits: 6,
      course: 1, semester: 'C1', type: 'obligatoria',
      groups: buildGroups('cin', [
        { name: 'Turno 1', sessions: [s(3,8,10), s(0,10,12)] },
        { name: 'Turno 2', sessions: [s(1,8,10), s(3,10,12)] },
        { name: 'Turno 3', sessions: [s(0,15,17), s(3,15,17)] },
      ]),
    },
    {
      id: 'fp', name: 'Fundamentos de Programación', code: '2060001', credits: 12,
      course: 1, semester: 'A', type: 'obligatoria',
      groups: buildGroups('fp', [
        { name: 'Turno 1 (C1)', sessions: [s(2,10,12), s(4,10,12)] },
        { name: 'Turno 2 (C1)', sessions: [s(0,8,10), s(2,10,12)] },
        { name: 'Turno 3 (C1)', sessions: [s(2,17,19), s(4,17,19)] },
        { name: 'Turno 1 (C2)', sessions: [s(2,8,10), s(4,10,12)] },
        { name: 'Turno 2 (C2)', sessions: [s(0,8,10), s(2,10,12)] },
        { name: 'Turno 3 (C2)', sessions: [s(3,15,17), s(4,15,17), s(2,17,19)] },
      ]),
    },

    // ============ CURSO 1 - C2 ============
    {
      id: 'edc', name: 'Estructura de Computadores', code: '2060008', credits: 6,
      course: 1, semester: 'C2', type: 'obligatoria',
      groups: buildGroups('edc', [
        { name: 'Turno 1', sessions: [s(0,8,10), s(3,10,12), s(0,12,14), s(3,12,14)] },
        { name: 'Turno 2', sessions: [s(4,8,10), s(0,10,12), s(3,12,14), s(4,12,14)] },
        { name: 'Turno 3', sessions: [s(2,15,17), s(0,17,19), s(2,19,21), s(3,19,21)] },
      ]),
    },
    {
      id: 'est', name: 'Estadística', code: '2060007', credits: 6,
      course: 1, semester: 'C2', type: 'obligatoria',
      groups: buildGroups('est', [
        { name: 'Turno 1', sessions: [s(1,8,10), s(2,10,12)] },
        { name: 'Turno 2', sessions: [s(3,8,10), s(1,10,12)] },
        { name: 'Turno 3', sessions: [s(3,15,17), s(1,17,19)] },
      ]),
    },
    {
      id: 'ae', name: 'Administración de Empresas', code: '2060002', credits: 6,
      course: 1, semester: 'C2', type: 'obligatoria',
      groups: buildGroups('ae', [
        { name: 'Turno 1', sessions: [s(3,8,10), s(0,10,12)] },
        { name: 'Turno 2', sessions: [s(4,10,12), s(2,12,14)] },
        { name: 'Turno 3', sessions: [s(0,15,17), s(3,17,19)] },
      ]),
    },
    {
      id: 'aln', name: 'Álgebra Lineal y Numérica', code: '2060006', credits: 6,
      course: 1, semester: 'C2', type: 'obligatoria',
      groups: buildGroups('aln', [
        { name: 'Turno 1', sessions: [s(4,8,10), s(1,10,12)] },
        { name: 'Turno 2', sessions: [s(1,8,10), s(3,10,12)] },
        { name: 'Turno 3', sessions: [s(1,15,17), s(4,17,19)] },
      ]),
    },

    // ============ CURSO 2 - C1 ============
    {
      id: 'adda', name: 'Análisis y Diseño de Datos y Algoritmos', code: '2060010', credits: 12,
      course: 2, semester: 'A', type: 'obligatoria',
      groups: buildGroups('adda', [
        { name: 'Turno 1 (C1)', sessions: [s(0,8,10), s(2,10,12)] },
        { name: 'Turno 2 (C1)', sessions: [s(1,12,14), s(3,10,12)] },
        { name: 'Turno 3 (C1)', sessions: [s(0,15,17), s(2,17,19)] },
        { name: 'Turno 1 (C2)', sessions: [s(0,12,14), s(2,10,12)] },
        { name: 'Turno 2 (C2)', sessions: [s(1,12,14), s(2,12,14)] },
        { name: 'Turno 3 (C2)', sessions: [s(0,17,19), s(2,17,19)] },
      ]),
    },
    {
      id: 'iissi1', name: 'Intro. Ingeniería del Software y SI I', code: '2060054', credits: 6,
      course: 2, semester: 'C1', type: 'obligatoria',
      groups: buildGroups('iissi1', [
        { name: 'Turno 1', sessions: [s(1,8,10), s(3,10,12)] },
        { name: 'Turno 2', sessions: [s(1,10,12), s(3,12,14)] },
        { name: 'Turno 3', sessions: [s(1,15,17), s(3,17,19)] },
      ]),
    },
    {
      id: 'rc', name: 'Redes de Computadores', code: '2060014', credits: 6,
      course: 2, semester: 'C1', type: 'obligatoria',
      groups: buildGroups('rc', [
        { name: 'Turno 1', sessions: [s(0,10,12), s(3,8,10), s(3,12,14)] },
        { name: 'Turno 2', sessions: [s(0,8,10), s(2,12,14), s(3,8,10)] },
        { name: 'Turno 3', sessions: [s(0,17,19), s(3,15,17), s(3,19,21)] },
      ]),
    },
    {
      id: 'md', name: 'Matemática Discreta', code: '2060013', credits: 6,
      course: 2, semester: 'C1', type: 'obligatoria',
      groups: buildGroups('md', [
        { name: 'Turno 1', sessions: [s(1,10,12), s(4,8,10), s(4,12,14)] },
        { name: 'Turno 2', sessions: [s(0,12,14), s(4,10,12), s(4,12,14)] },
        { name: 'Turno 3', sessions: [s(1,17,19), s(4,15,17)] },
      ]),
    },
    {
      id: 'li', name: 'Lógica Informática', code: '2060012', credits: 6,
      course: 2, semester: 'C1', type: 'optativa',
      groups: buildGroups('li', [
        { name: 'Turno 1', sessions: [s(2,8,10), s(4,10,12)] },
        { name: 'Turno 2', sessions: [s(1,8,10), s(4,8,10)] },
        { name: 'Turno 3', sessions: [s(2,15,17), s(4,17,19)] },
      ]),
    },

    // ============ CURSO 2 - C2 ============
    {
      id: 'ac', name: 'Arquitectura de Computadores', code: '2060015', credits: 6,
      course: 2, semester: 'C2', type: 'obligatoria',
      groups: buildGroups('ac', [
        { name: 'Turno 1', sessions: [s(0,10,12), s(2,8,10), s(3,8,10), s(4,8,10)] },
        { name: 'Turno 2', sessions: [s(0,8,10), s(4,8,10), s(4,10,12)] },
        { name: 'Turno 3', sessions: [s(0,15,17), s(3,15,17), s(3,19,21)] },
      ]),
    },
    {
      id: 'iissi2', name: 'Intro. Ingeniería del Software y SI II', code: '2060055', credits: 6,
      course: 2, semester: 'C2', type: 'obligatoria',
      groups: buildGroups('iissi2', [
        { name: 'Turno 1', sessions: [s(1,8,10), s(3,10,12)] },
        { name: 'Turno 2', sessions: [s(2,10,12), s(3,12,14)] },
        { name: 'Turno 3', sessions: [s(1,15,17), s(3,17,19)] },
      ]),
    },
    {
      id: 'so', name: 'Sistemas Operativos', code: '2060017', credits: 6,
      course: 2, semester: 'C2', type: 'obligatoria',
      groups: buildGroups('so', [
        { name: 'Turno 1', sessions: [s(1,10,12), s(4,10,12)] },
        { name: 'Turno 2', sessions: [s(0,10,12), s(4,12,14)] },
        { name: 'Turno 3', sessions: [s(1,17,19), s(4,17,19)] },
      ]),
    },
    {
      id: 'ar', name: 'Arquitectura de Redes', code: '2060016', credits: 6,
      course: 2, semester: 'C2', type: 'optativa',
      groups: buildGroups('ar', [
        { name: 'Turno 1', sessions: [s(0,8,10), s(2,8,10), s(2,12,14), s(4,12,14)] },
        { name: 'Turno 2', sessions: [s(1,8,10), s(2,8,10), s(3,10,12)] },
        { name: 'Turno 3', sessions: [s(2,15,17), s(4,15,17), s(2,19,21)] },
      ]),
    },

    // ============ CURSO 3 - C1 ============
    {
      id: 'ia', name: 'Inteligencia Artificial', code: '2060021', credits: 6,
      course: 3, semester: 'C1', type: 'obligatoria',
      groups: buildGroups('ia', [
        { name: 'Turno 1 - Grupo 1', sessions: [s(1,10,12), s(3,12,14)] },
        { name: 'Turno 1 - Grupo 2', sessions: [s(3,8,10), s(1,12,14)] },
        { name: 'Turno 1 - Grupo 3', sessions: [s(1,15,17), s(4,17,19)] },
      ]),
    },
    {
      id: 'cimsi', name: 'Config., Impl. y Mant. de SI', code: '2060018', credits: 6,
      course: 3, semester: 'C1', type: 'optativa',
      groups: buildGroups('cimsi', [
        { name: 'Turno 1', sessions: [s(0,8,10), s(0,10,12), s(3,10,12)] },
      ]),
    },
    {
      id: 'gsi', name: 'Gestión de Sistemas de Información', code: '2060019', credits: 6,
      course: 3, semester: 'C1', type: 'optativa',
      groups: buildGroups('gsi', [
        { name: 'Turno 1', sessions: [s(0,8,10), s(0,10,12), s(2,10,12), s(3,19,21)] },
      ]),
    },
    {
      id: 'pl', name: 'Procesadores de Lenguajes', code: '2060022', credits: 6,
      course: 3, semester: 'C1', type: 'optativa',
      groups: buildGroups('pl', [
        { name: 'Grupo 1', sessions: [s(2,8,10), s(2,12,14), s(3,15,17)] },
        { name: 'Grupo 2', sessions: [s(0,12,14), s(1,17,19), s(3,17,19)] },
      ]),
    },
    {
      id: 'pd', name: 'Programación Declarativa', code: '2060023', credits: 6,
      course: 3, semester: 'C1', type: 'optativa',
      groups: buildGroups('pd', [
        { name: 'Grupo 1', sessions: [s(1,17,19), s(3,15,17)] },
        { name: 'Grupo 2', sessions: [s(0,12,14), s(2,8,10)] },
      ]),
    },
    {
      id: 'tai', name: 'Tecnologías Avanzadas de la Información', code: '2060024', credits: 6,
      course: 3, semester: 'C1', type: 'optativa',
      groups: buildGroups('tai', [
        { name: 'Turno 1', sessions: [s(4,8,10), s(4,12,14), s(2,12,14), s(2,17,19), s(2,19,21)] },
      ]),
    },
    {
      id: 'gee', name: 'Gestión y Estrategia Empresarial', code: '2060020', credits: 6,
      course: 3, semester: 'C1', type: 'optativa',
      groups: buildGroups('gee', [
        { name: 'Turno 1', sessions: [s(0,17,19), s(4,15,17)] },
      ]),
    },

    // ============ CURSO 3 - C2 ============
    {
      id: 'asd', name: 'Arquitectura de Sistemas Distribuidos', code: '2060026', credits: 6,
      course: 3, semester: 'C2', type: 'optativa',
      groups: buildGroups('asd', [
        { name: 'Turno 1', sessions: [s(1,8,10), s(0,10,12), s(0,12,14), s(0,15,17)] },
      ]),
    },
    {
      id: 'aia', name: 'Ampliación de Inteligencia Artificial', code: '2060025', credits: 6,
      course: 3, semester: 'C2', type: 'optativa',
      groups: buildGroups('aia', [
        { name: 'Turno 1', sessions: [s(2,10,12), s(3,12,14), s(3,15,17)] },
      ]),
    },
    {
      id: 'masi', name: 'Matemática Aplicada a SI', code: '2060027', credits: 6,
      course: 3, semester: 'C2', type: 'optativa',
      groups: buildGroups('masi', [
        { name: 'Grupo 1', sessions: [s(3,8,10), s(2,12,14), s(2,15,17)] },
        { name: 'Grupo 2', sessions: [s(0,17,19), s(2,15,17)] },
      ]),
    },
    {
      id: 'sie', name: 'Sistemas de Información Empresariales', code: '2060028', credits: 6,
      course: 3, semester: 'C2', type: 'optativa',
      groups: buildGroups('sie', [
        { name: 'Grupo 1', sessions: [s(1,10,12), s(3,10,12), s(3,12,14)] },
        { name: 'Grupo 2', sessions: [s(1,15,17), s(3,17,19), s(3,15,17)] },
      ]),
    },
    {
      id: 'si', name: 'Sistemas Inteligentes', code: '2060029', credits: 6,
      course: 3, semester: 'C2', type: 'optativa',
      groups: buildGroups('si', [
        { name: 'Grupo 1', sessions: [s(2,8,10), s(3,10,12)] },
        { name: 'Grupo 2', sessions: [s(0,8,10), s(4,12,14)] },
        { name: 'Grupo 3', sessions: [s(1,12,14), s(2,17,19)] },
      ]),
    },
    {
      id: 'sos', name: 'Sistemas Orientados a Servicios', code: '2060030', credits: 6,
      course: 3, semester: 'C2', type: 'optativa',
      groups: buildGroups('sos', [
        { name: 'Turno 1', sessions: [s(4,10,12), s(0,12,14), s(0,15,17)] },
      ]),
    },

    // ============ CURSO 4 - C1 ============
    {
      id: 'pgpi', name: 'Planificación y Gestión de Proyectos Informáticos', code: '2060040', credits: 6,
      course: 4, semester: 'C1', type: 'obligatoria',
      groups: buildGroups('pgpi', [
        { name: 'Grupo 1', sessions: [s(3,8,10), s(1,12,14)] },
        { name: 'Grupo 2', sessions: [s(3,15,17), s(1,17,19)] },
      ]),
    },
    {
      id: 'mc', name: 'Matemáticas para la Computación', code: '2060039', credits: 6,
      course: 4, semester: 'C1', type: 'optativa',
      groups: buildGroups('mc', [
        { name: 'Turno 1', sessions: [s(0,8,10), s(0,10,12), s(0,12,14)] },
      ]),
    },
    {
      id: 'ssii', name: 'Seguridad en Sistemas Informáticos e Internet', code: '2060042', credits: 6,
      course: 4, semester: 'C1', type: 'optativa',
      groups: buildGroups('ssii', [
        { name: 'Turno 1', sessions: [s(1,8,10), s(4,10,12), s(2,8,10), s(2,12,14)] },
      ]),
    },
    {
      id: 'isi', name: 'Infraestructura de Sistemas de Información', code: '2060035', credits: 6,
      course: 4, semester: 'C1', type: 'optativa',
      groups: buildGroups('isi', [
        { name: 'Turno 1', sessions: [s(4,8,10), s(2,10,12), s(2,12,14)] },
      ]),
    },
    {
      id: 'gps', name: 'Gestión de Procesos y Servicios', code: '2060034', credits: 6,
      course: 4, semester: 'C1', type: 'optativa',
      groups: buildGroups('gps', [
        { name: 'Turno 1', sessions: [s(1,10,12), s(4,12,14)] },
      ]),
    },
    {
      id: 'mati', name: 'Matemática Aplicada a TI', code: '2060038', credits: 6,
      course: 4, semester: 'C1', type: 'optativa',
      groups: buildGroups('mati', [
        { name: 'Turno 1', sessions: [s(0,15,17), s(0,17,19), s(4,15,17)] },
      ]),
    },
    {
      id: 'ipo', name: 'Interacción Persona-ordenador', code: '2060037', credits: 6,
      course: 4, semester: 'C1', type: 'optativa',
      groups: buildGroups('ipo', [
        { name: 'Turno 1', sessions: [s(0,15,17), s(0,17,19), s(2,17,19), s(0,19,21)] },
      ]),
    },
    {
      id: 'asi', name: 'Administración de Sistemas de Información', code: '2060033', credits: 6,
      course: 4, semester: 'C1', type: 'optativa',
      groups: buildGroups('asi', [
        { name: 'Turno 1', sessions: [s(1,15,17), s(3,15,17), s(3,17,19)] },
      ]),
    },
    {
      id: 'pid', name: 'Procesamiento de Imágenes Digitales', code: '2060041', credits: 6,
      course: 4, semester: 'C1', type: 'optativa',
      groups: buildGroups('pid', [
        { name: 'Turno 1', sessions: [s(2,15,17), s(4,17,19)] },
      ]),
    },
    {
      id: 't', name: 'Telemática', code: '2060043', credits: 6,
      course: 4, semester: 'C1', type: 'optativa',
      groups: buildGroups('t', [
        { name: 'Turno 1', sessions: [s(0,10,12), s(0,12,14), s(3,10,12)] },
      ]),
    },

    // ============ CURSO 4 - C2 ============
    {
      id: 'tfg', name: 'Trabajo Fin de Grado', code: '2060053', credits: 12,
      course: 4, semester: 'C2', type: 'obligatoria',
      groups: [],
    },
    {
      id: 'mcc', name: 'Modelos de Computación y Complejidad', code: '2060051', credits: 6,
      course: 4, semester: 'C2', type: 'optativa',
      groups: buildGroups('mcc', [
        { name: 'Turno 1', sessions: [s(0,8,10), s(3,12,14)] },
      ]),
    },
    {
      id: 'marsi', name: 'Modelado y Análisis de Requisitos en SI', code: '2060050', credits: 6,
      course: 4, semester: 'C2', type: 'optativa',
      groups: buildGroups('marsi', [
        { name: 'Turno 1', sessions: [s(1,8,10), s(3,10,12)] },
      ]),
    },
    {
      id: 'gp', name: 'Gestión de la Producción', code: '2060048', credits: 6,
      course: 4, semester: 'C2', type: 'optativa',
      groups: buildGroups('gp', [
        { name: 'Turno 1', sessions: [s(2,8,10), s(0,10,12)] },
      ]),
    },
    {
      id: 'aii', name: 'Acceso Inteligente a la Información', code: '2060032', credits: 6,
      course: 4, semester: 'C2', type: 'optativa',
      groups: buildGroups('aii', [
        { name: 'Turno 1', sessions: [s(4,8,10), s(0,10,12), s(3,12,14), s(4,12,14)] },
      ]),
    },
    {
      id: 'ie', name: 'Inteligencia Empresarial', code: '2060049', credits: 6,
      course: 4, semester: 'C2', type: 'optativa',
      groups: buildGroups('ie', [
        { name: 'Turno 1', sessions: [s(1,10,12), s(1,12,14)] },
      ]),
    },
    {
      id: 'asc', name: 'Aplicaciones de Soft Computing', code: '2060044', credits: 6,
      course: 4, semester: 'C2', type: 'optativa',
      groups: buildGroups('asc', [
        { name: 'Turno 1', sessions: [s(0,8,10), s(0,12,14)] },
      ]),
    },
    {
      id: 'crip', name: 'Criptografía', code: '2060046', credits: 6,
      course: 4, semester: 'C2', type: 'optativa',
      groups: buildGroups('crip', [
        { name: 'Turno 1', sessions: [s(2,12,14), s(4,10,12)] },
      ]),
    },
    {
      id: 'cm', name: 'Computación Móvil', code: '2060045', credits: 6,
      course: 4, semester: 'C2', type: 'optativa',
      groups: buildGroups('cm', [
        { name: 'Turno 1', sessions: [s(0,15,17), s(2,15,17), s(2,19,21)] },
      ]),
    },
    {
      id: 'tis', name: 'Tecnología, Informática y Sociedad', code: '2060052', credits: 6,
      course: 4, semester: 'C2', type: 'optativa',
      groups: buildGroups('tis', [
        { name: 'Turno 1', sessions: [s(1,15,17), s(3,15,17), s(3,17,19)] },
      ]),
    },
    {
      id: 'ecomp', name: 'Estadística Computacional', code: '2060047', credits: 6,
      course: 4, semester: 'C2', type: 'optativa',
      groups: buildGroups('ecomp', [
        { name: 'Turno 1', sessions: [s(0,17,19), s(2,17,19)] },
      ]),
    },
  ],
};
