export interface Subject {
  id: string;
  name: string;
  code: string;
  credits: number;
  course: number;
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
  { id: 'info', name: 'Grado en Ingeniería Informática' },
  { id: 'ade', name: 'Grado en Administración de Empresas' },
  { id: 'derecho', name: 'Grado en Derecho' },
];

const COLORS = [
  'hsl(217 45% 20%)',    // navy
  'hsl(42 50% 54%)',     // gold
  'hsl(213 35% 35%)',    // blue-mid
  'hsl(160 40% 40%)',    // teal
  'hsl(340 45% 50%)',    // rose
  'hsl(270 35% 45%)',    // purple
  'hsl(25 55% 50%)',     // amber
  'hsl(190 50% 40%)',    // cyan
];

export function getSubjectColor(index: number): string {
  return COLORS[index % COLORS.length];
}

export const SUBJECTS: Record<string, Subject[]> = {
  info: [
    {
      id: 'calc', name: 'Cálculo', code: 'INF101', credits: 6, course: 1,
      groups: [
        { id: 'calc-a', name: 'Grupo A', professor: 'Dr. García', type: 'theory', sessions: [{ day: 0, startHour: 9, endHour: 11 }, { day: 2, startHour: 9, endHour: 11 }] },
        { id: 'calc-b', name: 'Grupo B', professor: 'Dra. López', type: 'theory', sessions: [{ day: 1, startHour: 11, endHour: 13 }, { day: 3, startHour: 11, endHour: 13 }] },
      ],
    },
    {
      id: 'prog1', name: 'Programación I', code: 'INF102', credits: 6, course: 1,
      groups: [
        { id: 'prog1-a', name: 'Grupo A', professor: 'Dr. Martínez', type: 'theory', sessions: [{ day: 0, startHour: 11, endHour: 13 }, { day: 3, startHour: 9, endHour: 11 }] },
        { id: 'prog1-b', name: 'Grupo B', professor: 'Dr. Ruiz', type: 'theory', sessions: [{ day: 1, startHour: 9, endHour: 11 }, { day: 4, startHour: 9, endHour: 11 }] },
        { id: 'prog1-lab', name: 'Lab 1', professor: 'Dr. Martínez', type: 'lab', sessions: [{ day: 4, startHour: 15, endHour: 17 }] },
      ],
    },
    {
      id: 'alg', name: 'Álgebra Lineal', code: 'INF103', credits: 6, course: 1,
      groups: [
        { id: 'alg-a', name: 'Grupo A', professor: 'Dra. Fernández', type: 'theory', sessions: [{ day: 2, startHour: 11, endHour: 13 }, { day: 4, startHour: 11, endHour: 13 }] },
        { id: 'alg-b', name: 'Grupo B', professor: 'Dr. Navarro', type: 'theory', sessions: [{ day: 0, startHour: 15, endHour: 17 }, { day: 2, startHour: 15, endHour: 17 }] },
      ],
    },
    {
      id: 'fis', name: 'Física', code: 'INF104', credits: 6, course: 1,
      groups: [
        { id: 'fis-a', name: 'Grupo A', professor: 'Dr. Sánchez', type: 'theory', sessions: [{ day: 1, startHour: 15, endHour: 17 }, { day: 3, startHour: 15, endHour: 17 }] },
        { id: 'fis-b', name: 'Grupo B', professor: 'Dra. Torres', type: 'theory', sessions: [{ day: 0, startHour: 13, endHour: 15 }, { day: 2, startHour: 13, endHour: 15 }] },
      ],
    },
    {
      id: 'bd', name: 'Bases de Datos', code: 'INF201', credits: 6, course: 2,
      groups: [
        { id: 'bd-a', name: 'Grupo A', professor: 'Dr. Pérez', type: 'theory', sessions: [{ day: 1, startHour: 9, endHour: 11 }, { day: 3, startHour: 9, endHour: 11 }] },
        { id: 'bd-lab', name: 'Lab 1', professor: 'Dr. Pérez', type: 'lab', sessions: [{ day: 4, startHour: 11, endHour: 13 }] },
      ],
    },
    {
      id: 'so', name: 'Sistemas Operativos', code: 'INF202', credits: 6, course: 2,
      groups: [
        { id: 'so-a', name: 'Grupo A', professor: 'Dra. Díaz', type: 'theory', sessions: [{ day: 0, startHour: 9, endHour: 11 }, { day: 2, startHour: 11, endHour: 13 }] },
        { id: 'so-b', name: 'Grupo B', professor: 'Dr. Moreno', type: 'theory', sessions: [{ day: 1, startHour: 15, endHour: 17 }, { day: 3, startHour: 13, endHour: 15 }] },
      ],
    },
  ],
  ade: [
    {
      id: 'eco1', name: 'Economía I', code: 'ADE101', credits: 6, course: 1,
      groups: [
        { id: 'eco1-a', name: 'Grupo A', professor: 'Dr. Blanco', type: 'theory', sessions: [{ day: 0, startHour: 9, endHour: 11 }, { day: 2, startHour: 9, endHour: 11 }] },
        { id: 'eco1-b', name: 'Grupo B', professor: 'Dra. Ramos', type: 'theory', sessions: [{ day: 1, startHour: 11, endHour: 13 }, { day: 3, startHour: 11, endHour: 13 }] },
      ],
    },
    {
      id: 'conta', name: 'Contabilidad', code: 'ADE102', credits: 6, course: 1,
      groups: [
        { id: 'conta-a', name: 'Grupo A', professor: 'Dr. Vega', type: 'theory', sessions: [{ day: 0, startHour: 11, endHour: 13 }, { day: 3, startHour: 9, endHour: 11 }] },
        { id: 'conta-b', name: 'Grupo B', professor: 'Dra. Ortiz', type: 'theory', sessions: [{ day: 1, startHour: 9, endHour: 11 }, { day: 4, startHour: 9, endHour: 11 }] },
      ],
    },
    {
      id: 'mkt', name: 'Marketing', code: 'ADE201', credits: 6, course: 2,
      groups: [
        { id: 'mkt-a', name: 'Grupo A', professor: 'Dr. Castro', type: 'theory', sessions: [{ day: 2, startHour: 15, endHour: 17 }, { day: 4, startHour: 15, endHour: 17 }] },
      ],
    },
  ],
  derecho: [
    {
      id: 'civil', name: 'Derecho Civil', code: 'DER101', credits: 6, course: 1,
      groups: [
        { id: 'civil-a', name: 'Grupo A', professor: 'Dra. Molina', type: 'theory', sessions: [{ day: 0, startHour: 9, endHour: 11 }, { day: 2, startHour: 9, endHour: 11 }] },
      ],
    },
    {
      id: 'penal', name: 'Derecho Penal', code: 'DER102', credits: 6, course: 1,
      groups: [
        { id: 'penal-a', name: 'Grupo A', professor: 'Dr. Herrera', type: 'theory', sessions: [{ day: 1, startHour: 9, endHour: 11 }, { day: 3, startHour: 9, endHour: 11 }] },
      ],
    },
  ],
};
