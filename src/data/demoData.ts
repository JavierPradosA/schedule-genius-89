export interface Subject {
  id: string;
  name: string;
  code: string;
  credits: number;
  course: number;
  semester: 'C1' | 'C2' | 'A'; // C1=1er cuatrimestre, C2=2do, A=anual
  type: 'obligatoria' | 'optativa';
  mention?: string; // For optativas linked to a mention
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
export const HOURS = Array.from({ length: 12 }, (_, i) => i + 8); // 8:00 - 19:00

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

// Helper to generate groups with realistic sessions
function makeGroups(id: string, sessions: { theory: Session[][]; lab?: Session[][] }): SubjectGroup[] {
  const professors = [
    'Dr. García', 'Dra. López', 'Dr. Martínez', 'Dra. Fernández', 'Dr. Ruiz',
    'Dra. Sánchez', 'Dr. Navarro', 'Dra. Torres', 'Dr. Pérez', 'Dra. Díaz',
    'Dr. Moreno', 'Dra. Ortiz', 'Dr. Herrera', 'Dra. Molina', 'Dr. Vega',
    'Dr. Blanco', 'Dra. Ramos', 'Dr. Castro', 'Dra. Reyes', 'Dr. Romero',
  ];
  let pi = Math.abs(id.split('').reduce((a, c) => a + c.charCodeAt(0), 0)) % professors.length;
  const groups: SubjectGroup[] = [];

  sessions.theory.forEach((s, i) => {
    groups.push({
      id: `${id}-t${i}`,
      name: `Grupo ${String.fromCharCode(65 + i)}`,
      professor: professors[(pi + i) % professors.length],
      type: 'theory',
      sessions: s,
    });
  });

  sessions.lab?.forEach((s, i) => {
    groups.push({
      id: `${id}-lab${i}`,
      name: `Lab ${i + 1}`,
      professor: professors[(pi + i + 2) % professors.length],
      type: 'lab',
      sessions: s,
    });
  });

  return groups;
}

export const SUBJECTS: Record<string, Subject[]> = {
  giti: [
    // ===== CURSO 1 =====
    {
      id: 'fp', name: 'Fundamentos de Programación', code: '2060001', credits: 12, course: 1, semester: 'A', type: 'obligatoria',
      groups: makeGroups('fp', {
        theory: [
          [{ day: 0, startHour: 9, endHour: 11 }, { day: 2, startHour: 9, endHour: 11 }],
          [{ day: 1, startHour: 11, endHour: 13 }, { day: 3, startHour: 11, endHour: 13 }],
          [{ day: 0, startHour: 15, endHour: 17 }, { day: 2, startHour: 15, endHour: 17 }],
        ],
        lab: [
          [{ day: 4, startHour: 9, endHour: 11 }],
          [{ day: 4, startHour: 11, endHour: 13 }],
          [{ day: 4, startHour: 15, endHour: 17 }],
        ],
      }),
    },
    {
      id: 'cin', name: 'Cálculo Infinitesimal y Numérico', code: '2060003', credits: 6, course: 1, semester: 'C1', type: 'obligatoria',
      groups: makeGroups('cin', {
        theory: [
          [{ day: 0, startHour: 11, endHour: 13 }, { day: 2, startHour: 11, endHour: 13 }],
          [{ day: 1, startHour: 9, endHour: 11 }, { day: 3, startHour: 9, endHour: 11 }],
        ],
      }),
    },
    {
      id: 'ced', name: 'Circuitos Electrónicos Digitales', code: '2060004', credits: 6, course: 1, semester: 'C1', type: 'obligatoria',
      groups: makeGroups('ced', {
        theory: [
          [{ day: 1, startHour: 15, endHour: 17 }, { day: 3, startHour: 15, endHour: 17 }],
          [{ day: 0, startHour: 13, endHour: 15 }, { day: 2, startHour: 13, endHour: 15 }],
        ],
        lab: [
          [{ day: 4, startHour: 13, endHour: 15 }],
        ],
      }),
    },
    {
      id: 'ffi', name: 'Fundamentos Físicos de la Informática', code: '2060009', credits: 6, course: 1, semester: 'C1', type: 'obligatoria',
      groups: makeGroups('ffi', {
        theory: [
          [{ day: 3, startHour: 9, endHour: 11 }, { day: 4, startHour: 9, endHour: 11 }],
          [{ day: 1, startHour: 13, endHour: 15 }, { day: 3, startHour: 13, endHour: 15 }],
        ],
      }),
    },
    {
      id: 'imd', name: 'Introducción a la Matemática Discreta', code: '2060005', credits: 6, course: 1, semester: 'C1', type: 'obligatoria',
      groups: makeGroups('imd', {
        theory: [
          [{ day: 2, startHour: 9, endHour: 11 }, { day: 4, startHour: 11, endHour: 13 }],
          [{ day: 0, startHour: 17, endHour: 19 }, { day: 2, startHour: 17, endHour: 19 }],
        ],
      }),
    },
    {
      id: 'ae', name: 'Administración de Empresas', code: '2060002', credits: 6, course: 1, semester: 'C2', type: 'obligatoria',
      groups: makeGroups('ae', {
        theory: [
          [{ day: 0, startHour: 11, endHour: 13 }, { day: 2, startHour: 11, endHour: 13 }],
          [{ day: 1, startHour: 9, endHour: 11 }, { day: 3, startHour: 9, endHour: 11 }],
        ],
      }),
    },
    {
      id: 'aln', name: 'Álgebra Lineal y Numérica', code: '2060006', credits: 6, course: 1, semester: 'C2', type: 'obligatoria',
      groups: makeGroups('aln', {
        theory: [
          [{ day: 1, startHour: 11, endHour: 13 }, { day: 3, startHour: 11, endHour: 13 }],
          [{ day: 0, startHour: 9, endHour: 11 }, { day: 2, startHour: 9, endHour: 11 }],
        ],
      }),
    },
    {
      id: 'est', name: 'Estadística', code: '2060007', credits: 6, course: 1, semester: 'C2', type: 'obligatoria',
      groups: makeGroups('est', {
        theory: [
          [{ day: 0, startHour: 13, endHour: 15 }, { day: 2, startHour: 13, endHour: 15 }],
          [{ day: 1, startHour: 15, endHour: 17 }, { day: 3, startHour: 15, endHour: 17 }],
        ],
      }),
    },
    {
      id: 'ec', name: 'Estructura de Computadores', code: '2060008', credits: 6, course: 1, semester: 'C2', type: 'obligatoria',
      groups: makeGroups('ec', {
        theory: [
          [{ day: 1, startHour: 13, endHour: 15 }, { day: 3, startHour: 13, endHour: 15 }],
          [{ day: 4, startHour: 9, endHour: 11 }, { day: 4, startHour: 15, endHour: 17 }],
        ],
        lab: [
          [{ day: 4, startHour: 11, endHour: 13 }],
        ],
      }),
    },

    // ===== CURSO 2 =====
    {
      id: 'adda', name: 'Análisis y Diseño de Datos y Algoritmos', code: '2060010', credits: 12, course: 2, semester: 'A', type: 'obligatoria',
      groups: makeGroups('adda', {
        theory: [
          [{ day: 0, startHour: 9, endHour: 11 }, { day: 2, startHour: 9, endHour: 11 }],
          [{ day: 1, startHour: 9, endHour: 11 }, { day: 3, startHour: 9, endHour: 11 }],
        ],
        lab: [
          [{ day: 4, startHour: 9, endHour: 11 }],
          [{ day: 4, startHour: 11, endHour: 13 }],
        ],
      }),
    },
    {
      id: 'issi1', name: 'Intro. Ingeniería del Software y SI I', code: '2060054', credits: 6, course: 2, semester: 'C1', type: 'obligatoria',
      groups: makeGroups('issi1', {
        theory: [
          [{ day: 0, startHour: 11, endHour: 13 }, { day: 2, startHour: 11, endHour: 13 }],
          [{ day: 1, startHour: 11, endHour: 13 }, { day: 3, startHour: 11, endHour: 13 }],
        ],
      }),
    },
    {
      id: 'md', name: 'Matemática Discreta', code: '2060013', credits: 6, course: 2, semester: 'C1', type: 'obligatoria',
      groups: makeGroups('md', {
        theory: [
          [{ day: 1, startHour: 15, endHour: 17 }, { day: 3, startHour: 15, endHour: 17 }],
          [{ day: 0, startHour: 15, endHour: 17 }, { day: 2, startHour: 15, endHour: 17 }],
        ],
      }),
    },
    {
      id: 'rc', name: 'Redes de Computadores', code: '2060014', credits: 6, course: 2, semester: 'C1', type: 'obligatoria',
      groups: makeGroups('rc', {
        theory: [
          [{ day: 0, startHour: 13, endHour: 15 }, { day: 2, startHour: 13, endHour: 15 }],
          [{ day: 1, startHour: 13, endHour: 15 }, { day: 3, startHour: 13, endHour: 15 }],
        ],
      }),
    },
    {
      id: 'ac', name: 'Arquitectura de Computadores', code: '2060015', credits: 6, course: 2, semester: 'C2', type: 'obligatoria',
      groups: makeGroups('ac', {
        theory: [
          [{ day: 0, startHour: 11, endHour: 13 }, { day: 2, startHour: 11, endHour: 13 }],
          [{ day: 1, startHour: 15, endHour: 17 }, { day: 3, startHour: 15, endHour: 17 }],
        ],
      }),
    },
    {
      id: 'issi2', name: 'Intro. Ingeniería del Software y SI II', code: '2060055', credits: 6, course: 2, semester: 'C2', type: 'obligatoria',
      groups: makeGroups('issi2', {
        theory: [
          [{ day: 1, startHour: 11, endHour: 13 }, { day: 3, startHour: 11, endHour: 13 }],
          [{ day: 0, startHour: 13, endHour: 15 }, { day: 2, startHour: 13, endHour: 15 }],
        ],
      }),
    },
    {
      id: 'so', name: 'Sistemas Operativos', code: '2060017', credits: 6, course: 2, semester: 'C2', type: 'obligatoria',
      groups: makeGroups('so', {
        theory: [
          [{ day: 0, startHour: 9, endHour: 11 }, { day: 2, startHour: 9, endHour: 11 }],
          [{ day: 1, startHour: 9, endHour: 11 }, { day: 3, startHour: 9, endHour: 11 }],
        ],
        lab: [
          [{ day: 4, startHour: 15, endHour: 17 }],
        ],
      }),
    },
    // Optativas 2º
    {
      id: 'li', name: 'Lógica Informática', code: '2060012', credits: 6, course: 2, semester: 'C1', type: 'optativa',
      groups: makeGroups('li', {
        theory: [
          [{ day: 0, startHour: 17, endHour: 19 }, { day: 2, startHour: 17, endHour: 19 }],
        ],
      }),
    },
    {
      id: 'ar', name: 'Arquitectura de Redes', code: '2060016', credits: 6, course: 2, semester: 'C2', type: 'optativa',
      groups: makeGroups('ar', {
        theory: [
          [{ day: 1, startHour: 17, endHour: 19 }, { day: 3, startHour: 17, endHour: 19 }],
        ],
      }),
    },

    // ===== CURSO 3 =====
    {
      id: 'ia', name: 'Inteligencia Artificial', code: '2060021', credits: 6, course: 3, semester: 'C1', type: 'obligatoria',
      groups: makeGroups('ia', {
        theory: [
          [{ day: 0, startHour: 9, endHour: 11 }, { day: 2, startHour: 9, endHour: 11 }],
          [{ day: 1, startHour: 9, endHour: 11 }, { day: 3, startHour: 9, endHour: 11 }],
        ],
      }),
    },
    {
      id: 'cimsi', name: 'Config., Impl. y Mant. de Sistemas Informáticos', code: '2060018', credits: 6, course: 3, semester: 'C1', type: 'optativa',
      groups: makeGroups('cimsi', {
        theory: [
          [{ day: 0, startHour: 11, endHour: 13 }, { day: 2, startHour: 11, endHour: 13 }],
        ],
        lab: [[{ day: 4, startHour: 9, endHour: 11 }]],
      }),
    },
    {
      id: 'gsi', name: 'Gestión de Sistemas de Información', code: '2060019', credits: 6, course: 3, semester: 'C1', type: 'optativa',
      groups: makeGroups('gsi', {
        theory: [
          [{ day: 1, startHour: 11, endHour: 13 }, { day: 3, startHour: 11, endHour: 13 }],
        ],
      }),
    },
    {
      id: 'gee', name: 'Gestión y Estrategia Empresarial', code: '2060020', credits: 6, course: 3, semester: 'C1', type: 'optativa',
      groups: makeGroups('gee', {
        theory: [
          [{ day: 0, startHour: 13, endHour: 15 }, { day: 2, startHour: 13, endHour: 15 }],
        ],
      }),
    },
    {
      id: 'pl', name: 'Procesadores de Lenguajes', code: '2060022', credits: 6, course: 3, semester: 'C1', type: 'optativa',
      groups: makeGroups('pl', {
        theory: [
          [{ day: 1, startHour: 13, endHour: 15 }, { day: 3, startHour: 13, endHour: 15 }],
        ],
      }),
    },
    {
      id: 'pd', name: 'Programación Declarativa', code: '2060023', credits: 6, course: 3, semester: 'C1', type: 'optativa',
      groups: makeGroups('pd', {
        theory: [
          [{ day: 1, startHour: 15, endHour: 17 }, { day: 3, startHour: 15, endHour: 17 }],
        ],
      }),
    },
    {
      id: 'tai', name: 'Tecnologías Avanzadas de la Información', code: '2060024', credits: 6, course: 3, semester: 'C1', type: 'optativa',
      groups: makeGroups('tai', {
        theory: [
          [{ day: 0, startHour: 15, endHour: 17 }, { day: 2, startHour: 15, endHour: 17 }],
        ],
      }),
    },
    {
      id: 'aia', name: 'Ampliación de Inteligencia Artificial', code: '2060025', credits: 6, course: 3, semester: 'C2', type: 'optativa',
      groups: makeGroups('aia', {
        theory: [
          [{ day: 0, startHour: 9, endHour: 11 }, { day: 2, startHour: 9, endHour: 11 }],
        ],
      }),
    },
    {
      id: 'asd', name: 'Arquitectura de Sistemas Distribuidos', code: '2060026', credits: 6, course: 3, semester: 'C2', type: 'optativa',
      groups: makeGroups('asd', {
        theory: [
          [{ day: 1, startHour: 9, endHour: 11 }, { day: 3, startHour: 9, endHour: 11 }],
        ],
      }),
    },
    {
      id: 'masi', name: 'Matemática Aplicada a SI', code: '2060027', credits: 6, course: 3, semester: 'C2', type: 'optativa',
      groups: makeGroups('masi', {
        theory: [
          [{ day: 0, startHour: 11, endHour: 13 }, { day: 2, startHour: 11, endHour: 13 }],
        ],
      }),
    },
    {
      id: 'sie', name: 'Sistemas de Información Empresariales', code: '2060028', credits: 6, course: 3, semester: 'C2', type: 'optativa',
      groups: makeGroups('sie', {
        theory: [
          [{ day: 1, startHour: 11, endHour: 13 }, { day: 3, startHour: 11, endHour: 13 }],
        ],
      }),
    },
    {
      id: 'si', name: 'Sistemas Inteligentes', code: '2060029', credits: 6, course: 3, semester: 'C2', type: 'optativa',
      groups: makeGroups('si', {
        theory: [
          [{ day: 1, startHour: 13, endHour: 15 }, { day: 3, startHour: 13, endHour: 15 }],
        ],
      }),
    },
    {
      id: 'sos', name: 'Sistemas Orientados a Servicios', code: '2060030', credits: 6, course: 3, semester: 'C2', type: 'optativa',
      groups: makeGroups('sos', {
        theory: [
          [{ day: 0, startHour: 15, endHour: 17 }, { day: 2, startHour: 15, endHour: 17 }],
        ],
      }),
    },

    // ===== CURSO 4 =====
    {
      id: 'pgpi', name: 'Planificación y Gestión de Proyectos Informáticos', code: '2060040', credits: 6, course: 4, semester: 'C1', type: 'obligatoria',
      groups: makeGroups('pgpi', {
        theory: [
          [{ day: 0, startHour: 9, endHour: 11 }, { day: 2, startHour: 9, endHour: 11 }],
          [{ day: 1, startHour: 9, endHour: 11 }, { day: 3, startHour: 9, endHour: 11 }],
        ],
      }),
    },
    {
      id: 'tfg', name: 'Trabajo Fin de Grado', code: '2060053', credits: 12, course: 4, semester: 'C2', type: 'obligatoria',
      groups: [],
    },
    {
      id: 'asi', name: 'Administración de Sistemas de Información', code: '2060033', credits: 6, course: 4, semester: 'C1', type: 'optativa',
      groups: makeGroups('asi', {
        theory: [
          [{ day: 0, startHour: 11, endHour: 13 }, { day: 2, startHour: 11, endHour: 13 }],
        ],
      }),
    },
    {
      id: 'gps', name: 'Gestión de Procesos y Servicios', code: '2060034', credits: 6, course: 4, semester: 'C1', type: 'optativa',
      groups: makeGroups('gps', {
        theory: [
          [{ day: 1, startHour: 11, endHour: 13 }, { day: 3, startHour: 11, endHour: 13 }],
        ],
      }),
    },
    {
      id: 'isi', name: 'Infraestructura de Sistemas de Información', code: '2060035', credits: 6, course: 4, semester: 'C1', type: 'optativa',
      groups: makeGroups('isi', {
        theory: [
          [{ day: 0, startHour: 13, endHour: 15 }, { day: 2, startHour: 13, endHour: 15 }],
        ],
      }),
    },
    {
      id: 'ipo', name: 'Interacción Persona-ordenador', code: '2060037', credits: 6, course: 4, semester: 'C1', type: 'optativa',
      groups: makeGroups('ipo', {
        theory: [
          [{ day: 1, startHour: 13, endHour: 15 }, { day: 3, startHour: 13, endHour: 15 }],
        ],
      }),
    },
    {
      id: 'mati', name: 'Matemática Aplicada a TI', code: '2060038', credits: 6, course: 4, semester: 'C1', type: 'optativa',
      groups: makeGroups('mati', {
        theory: [
          [{ day: 1, startHour: 15, endHour: 17 }, { day: 3, startHour: 15, endHour: 17 }],
        ],
      }),
    },
    {
      id: 'mc', name: 'Matemáticas para la Computación', code: '2060039', credits: 6, course: 4, semester: 'C1', type: 'optativa',
      groups: makeGroups('mc', {
        theory: [
          [{ day: 0, startHour: 15, endHour: 17 }, { day: 2, startHour: 15, endHour: 17 }],
        ],
      }),
    },
    {
      id: 'pid', name: 'Procesamiento de Imágenes Digitales', code: '2060041', credits: 6, course: 4, semester: 'C1', type: 'optativa',
      groups: makeGroups('pid', {
        theory: [
          [{ day: 0, startHour: 17, endHour: 19 }, { day: 2, startHour: 17, endHour: 19 }],
        ],
      }),
    },
    {
      id: 'ssii', name: 'Seguridad en Sistemas Informáticos e Internet', code: '2060042', credits: 6, course: 4, semester: 'C1', type: 'optativa',
      groups: makeGroups('ssii', {
        theory: [
          [{ day: 1, startHour: 17, endHour: 19 }, { day: 3, startHour: 17, endHour: 19 }],
        ],
      }),
    },
    {
      id: 'cm', name: 'Computación Móvil', code: '2060045', credits: 6, course: 4, semester: 'C2', type: 'optativa',
      groups: makeGroups('cm', {
        theory: [
          [{ day: 0, startHour: 9, endHour: 11 }, { day: 2, startHour: 9, endHour: 11 }],
        ],
      }),
    },
    {
      id: 'ie', name: 'Inteligencia Empresarial', code: '2060049', credits: 6, course: 4, semester: 'C2', type: 'optativa',
      groups: makeGroups('ie', {
        theory: [
          [{ day: 1, startHour: 9, endHour: 11 }, { day: 3, startHour: 9, endHour: 11 }],
        ],
      }),
    },
    {
      id: 'marsi', name: 'Modelado y Análisis de Requisitos en SI', code: '2060050', credits: 6, course: 4, semester: 'C2', type: 'optativa',
      groups: makeGroups('marsi', {
        theory: [
          [{ day: 0, startHour: 11, endHour: 13 }, { day: 2, startHour: 11, endHour: 13 }],
        ],
      }),
    },
    {
      id: 'mcc', name: 'Modelos de Computación y Complejidad', code: '2060051', credits: 6, course: 4, semester: 'C2', type: 'optativa',
      groups: makeGroups('mcc', {
        theory: [
          [{ day: 1, startHour: 11, endHour: 13 }, { day: 3, startHour: 11, endHour: 13 }],
        ],
      }),
    },
    {
      id: 'aii', name: 'Acceso Inteligente a la Información', code: '2060032', credits: 6, course: 4, semester: 'C2', type: 'optativa',
      groups: makeGroups('aii', {
        theory: [
          [{ day: 0, startHour: 13, endHour: 15 }, { day: 2, startHour: 13, endHour: 15 }],
        ],
      }),
    },
    {
      id: 'asc', name: 'Aplicaciones de Soft Computing', code: '2060044', credits: 6, course: 4, semester: 'C2', type: 'optativa',
      groups: makeGroups('asc', {
        theory: [
          [{ day: 1, startHour: 13, endHour: 15 }, { day: 3, startHour: 13, endHour: 15 }],
        ],
      }),
    },
    {
      id: 'crip', name: 'Criptografía', code: '2060046', credits: 6, course: 4, semester: 'C2', type: 'optativa',
      groups: makeGroups('crip', {
        theory: [
          [{ day: 0, startHour: 15, endHour: 17 }, { day: 2, startHour: 15, endHour: 17 }],
        ],
      }),
    },
    {
      id: 'ecomp', name: 'Estadística Computacional', code: '2060047', credits: 6, course: 4, semester: 'C2', type: 'optativa',
      groups: makeGroups('ecomp', {
        theory: [
          [{ day: 1, startHour: 15, endHour: 17 }, { day: 3, startHour: 15, endHour: 17 }],
        ],
      }),
    },
    {
      id: 'gp', name: 'Gestión de la Producción', code: '2060048', credits: 6, course: 4, semester: 'C2', type: 'optativa',
      groups: makeGroups('gp', {
        theory: [
          [{ day: 0, startHour: 17, endHour: 19 }, { day: 2, startHour: 17, endHour: 19 }],
        ],
      }),
    },
    {
      id: 'tis', name: 'Tecnología, Informática y Sociedad', code: '2060052', credits: 6, course: 4, semester: 'C2', type: 'optativa',
      groups: makeGroups('tis', {
        theory: [
          [{ day: 1, startHour: 17, endHour: 19 }, { day: 3, startHour: 17, endHour: 19 }],
        ],
      }),
    },
  ],
};
