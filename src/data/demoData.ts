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
  day: 0 | 1 | 2 | 3 | 4;
  startHour: number;
  endHour: number;
}

export interface TimeBlock {
  day: 0 | 1 | 2 | 3 | 4;
  startHour: number;
  endHour: number;
}

export const DAYS = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'] as const;

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
  { id: 'giti', name: 'Grado en Ingeniería Informática - Tecnologías Informáticas' },
];

export const MENTIONS = [
  { id: 'si', name: 'Sistemas de Información' },
  { id: 'ti', name: 'Tecnologías de la Información' },
  { id: 'comp', name: 'Computación' },
];

const COLORS = [
  "hsl(217 45% 20%)",
  "hsl(42 50% 54%)",
  "hsl(213 35% 35%)",
  "hsl(160 40% 40%)",
  "hsl(340 45% 50%)",
  "hsl(270 35% 45%)",
  "hsl(25 55% 50%)",
  "hsl(190 50% 40%)",
  "hsl(5 50% 45%)",
  "hsl(130 35% 35%)",
];

export function getSubjectColor(index: number): string {
  return COLORS[index % COLORS.length];
}

// Datos oficiales extraídos de la web de horarios ETSII y del plan de estudios US para el curso 2025-26.
export const SUBJECTS: Record<string, Subject[]> = {
  giti: [
    {
      id: "ae", name: "Administración de Empresas", code: "2060002", credits: 6,
      course: 1, semester: "C2", type: "obligatoria",
      groups: [
        {
          id: "ae-1t1-c2", name: "1T1 (C2)", professor: "Andres Padillo Eguia, Jose Miguel Vives Martinez", professors: ["Andres Padillo Eguia","Jose Miguel Vives Martinez"], type: "theory",
          sessions: [{ day: 0 as const, startHour: 10, endHour: 12 }, { day: 3 as const, startHour: 8, endHour: 10 }],
        },
        {
          id: "ae-1t2-c2", name: "1T2 (C2)", professor: "Jose Carlos Molina Gomez", professors: ["Jose Carlos Molina Gomez"], type: "theory",
          sessions: [{ day: 2 as const, startHour: 12, endHour: 14 }, { day: 4 as const, startHour: 10, endHour: 12 }],
        },
        {
          id: "ae-1t3-c2", name: "1T3 (C2)", professor: "Carlos Manuel Gomez Alvarez", professors: ["Carlos Manuel Gomez Alvarez"], type: "theory",
          sessions: [{ day: 0 as const, startHour: 15, endHour: 17 }, { day: 3 as const, startHour: 17, endHour: 19 }],
        },
      ],
    },
    {
      id: "aln", name: "Álgebra Lineal y Numérica", code: "2060006", credits: 6,
      course: 1, semester: "C2", type: "obligatoria",
      groups: [
        {
          id: "aln-1t1-c2", name: "1T1 (C2)", professor: "Manuel Jesus Soto Prieto, Pilar Gomez-caminero Tellez", professors: ["Manuel Jesus Soto Prieto","Pilar Gomez-caminero Tellez"], type: "theory",
          sessions: [{ day: 1 as const, startHour: 10, endHour: 12 }, { day: 4 as const, startHour: 8, endHour: 10 }],
        },
        {
          id: "aln-1t2-c2", name: "1T2 (C2)", professor: "Beatriz Silva Gallardo, Pilar Gomez-caminero Tellez, Rafael Robles Arias", professors: ["Beatriz Silva Gallardo","Pilar Gomez-caminero Tellez","Rafael Robles Arias"], type: "theory",
          sessions: [{ day: 1 as const, startHour: 8, endHour: 10 }, { day: 3 as const, startHour: 10, endHour: 12 }],
        },
        {
          id: "aln-1t3-c2", name: "1T3 (C2)", professor: "Miguel Navarro Castro, Pablo Terron Quintero, Pilar Gomez-caminero Tellez", professors: ["Miguel Navarro Castro","Pablo Terron Quintero","Pilar Gomez-caminero Tellez"], type: "theory",
          sessions: [{ day: 1 as const, startHour: 15, endHour: 17 }, { day: 4 as const, startHour: 17, endHour: 19 }],
        },
      ],
    },
    {
      id: "cin", name: "Cálculo Infinitesimal y Numérico", code: "2060003", credits: 6,
      course: 1, semester: "C1", type: "obligatoria",
      groups: [
        {
          id: "cin-1t1-c1", name: "1T1 (C1)", professor: "Rosario Arriola Hernandez, Beatriz Silva Gallardo, Alfonso Marquez Martinez", professors: ["Rosario Arriola Hernandez","Beatriz Silva Gallardo","Alfonso Marquez Martinez"], type: "theory",
          sessions: [{ day: 0 as const, startHour: 10, endHour: 12 }, { day: 3 as const, startHour: 8, endHour: 10 }],
        },
        {
          id: "cin-1t2-c1", name: "1T2 (C1)", professor: "Beatriz Silva Gallardo, Delia Garijo Royo", professors: ["Beatriz Silva Gallardo","Delia Garijo Royo"], type: "theory",
          sessions: [{ day: 1 as const, startHour: 8, endHour: 10 }, { day: 3 as const, startHour: 10, endHour: 12 }],
        },
        {
          id: "cin-1t3-c1", name: "1T3 (C1)", professor: "Beatriz Silva Gallardo, Socrates Cuadri Crespo, Alfonso Marquez Martinez", professors: ["Beatriz Silva Gallardo","Socrates Cuadri Crespo","Alfonso Marquez Martinez"], type: "theory",
          sessions: [{ day: 0 as const, startHour: 15, endHour: 17 }, { day: 3 as const, startHour: 15, endHour: 17 }],
        },
      ],
    },
    {
      id: "ced", name: "Circuitos Electrónicos Digitales", code: "2060004", credits: 6,
      course: 1, semester: "C1", type: "obligatoria",
      groups: [
        {
          id: "ced-1t1-c1", name: "1T1 (C1)", professor: "Maria Del Pilar Parra Fernandez, Alejandro Casado Galan, David Guerrero Martos", professors: ["Maria Del Pilar Parra Fernandez","Alejandro Casado Galan","David Guerrero Martos"], type: "theory",
          sessions: [{ day: 2 as const, startHour: 8, endHour: 10 }, { day: 2 as const, startHour: 12, endHour: 14 }, { day: 4 as const, startHour: 8, endHour: 10 }],
        },
        {
          id: "ced-1t2-c1", name: "1T2 (C1)", professor: "Maria Dolores Hernandez Velazquez, Isabel Maria Gomez Gonzalez, Paula Navarro Gonzalez", professors: ["Maria Dolores Hernandez Velazquez","Isabel Maria Gomez Gonzalez","Paula Navarro Gonzalez"], type: "theory",
          sessions: [{ day: 0 as const, startHour: 10, endHour: 12 }, { day: 4 as const, startHour: 8, endHour: 10 }, { day: 4 as const, startHour: 12, endHour: 14 }],
        },
        {
          id: "ced-1t3-c1", name: "1T3 (C1)", professor: "David Guerrero Martos, Daniel Martin Fernandez, Maria Del Pilar Parra Fernandez", professors: ["David Guerrero Martos","Daniel Martin Fernandez","Maria Del Pilar Parra Fernandez"], type: "theory",
          sessions: [{ day: 0 as const, startHour: 17, endHour: 19 }, { day: 2 as const, startHour: 15, endHour: 17 }, { day: 2 as const, startHour: 19, endHour: 21 }],
        },
      ],
    },
    {
      id: "edc", name: "Estructura de Computadores", code: "2060008", credits: 6,
      course: 1, semester: "C2", type: "obligatoria",
      groups: [
        {
          id: "edc-1t1-c2", name: "1T1 (C2)", professor: "Maria Del Pilar Parra Fernandez, Maria Dolores Hernandez Velazquez, Samuel Yanes Luis", professors: ["Maria Del Pilar Parra Fernandez","Maria Dolores Hernandez Velazquez","Samuel Yanes Luis"], type: "theory",
          sessions: [{ day: 0 as const, startHour: 8, endHour: 10 }, { day: 0 as const, startHour: 12, endHour: 14 }, { day: 3 as const, startHour: 10, endHour: 12 }, { day: 3 as const, startHour: 12, endHour: 14 }],
        },
        {
          id: "edc-1t2-c2", name: "1T2 (C2)", professor: "David Guerrero Martos, Samuel Yanes Luis, Isabel Maria Gomez Gonzalez", professors: ["David Guerrero Martos","Samuel Yanes Luis","Isabel Maria Gomez Gonzalez"], type: "theory",
          sessions: [{ day: 0 as const, startHour: 10, endHour: 12 }, { day: 3 as const, startHour: 12, endHour: 14 }, { day: 4 as const, startHour: 8, endHour: 10 }, { day: 4 as const, startHour: 12, endHour: 14 }],
        },
        {
          id: "edc-1t3-c2", name: "1T3 (C2)", professor: "Alberto Jesus Molina Cantero, David Guerrero Martos, Samuel Yanes Luis", professors: ["Alberto Jesus Molina Cantero","David Guerrero Martos","Samuel Yanes Luis"], type: "theory",
          sessions: [{ day: 0 as const, startHour: 17, endHour: 19 }, { day: 2 as const, startHour: 15, endHour: 17 }, { day: 2 as const, startHour: 19, endHour: 21 }, { day: 3 as const, startHour: 19, endHour: 21 }],
        },
      ],
    },
    {
      id: "fp", name: "Fundamentos de Programación", code: "2060001", credits: 12,
      course: 1, semester: "A", type: "obligatoria",
      groups: [
        {
          id: "fp-1t1-c1", name: "1T1 (C1)", professor: "Fermin Cruz Mata, Francisco Jose Galan Morillo, Patricia Jimenez Aguirre, Jose Enrique Sanchez Lopez", professors: ["Fermin Cruz Mata","Francisco Jose Galan Morillo","Patricia Jimenez Aguirre","Jose Enrique Sanchez Lopez"], type: "theory",
          sessions: [{ day: 2 as const, startHour: 10, endHour: 12 }, { day: 4 as const, startHour: 10, endHour: 12 }],
        },
        {
          id: "fp-1t1-c2", name: "1T1 (C2)", professor: "Fermin Cruz Mata, Francisco Jose Galan Morillo, Belen Ramos Gutierrez, Cristina Rubio Escudero", professors: ["Fermin Cruz Mata","Francisco Jose Galan Morillo","Belen Ramos Gutierrez","Cristina Rubio Escudero"], type: "theory",
          sessions: [{ day: 2 as const, startHour: 8, endHour: 10 }, { day: 4 as const, startHour: 10, endHour: 12 }],
        },
        {
          id: "fp-1t2-c1", name: "1T2 (C1)", professor: "Jose Mariano Gonzalez Romano, Fernando Enriquez De Salamanca Ros, Pablo Reina Jimenez", professors: ["Jose Mariano Gonzalez Romano","Fernando Enriquez De Salamanca Ros","Pablo Reina Jimenez"], type: "theory",
          sessions: [{ day: 0 as const, startHour: 8, endHour: 10 }, { day: 2 as const, startHour: 10, endHour: 12 }],
        },
        {
          id: "fp-1t2-c2", name: "1T2 (C2)", professor: "Jose Mariano Gonzalez Romano, María Dolores Acuña Garrido, Daniel Mateos Garcia", professors: ["Jose Mariano Gonzalez Romano","María Dolores Acuña Garrido","Daniel Mateos Garcia"], type: "theory",
          sessions: [{ day: 0 as const, startHour: 8, endHour: 10 }, { day: 2 as const, startHour: 10, endHour: 12 }],
        },
        {
          id: "fp-1t3-c1", name: "1T3 (C1)", professor: "Alfonso Maria De Bengoa Diaz, Daniel Mateos Garcia, Jose Enrique Sanchez Lopez", professors: ["Alfonso Maria De Bengoa Diaz","Daniel Mateos Garcia","Jose Enrique Sanchez Lopez"], type: "theory",
          sessions: [{ day: 2 as const, startHour: 17, endHour: 19 }, { day: 4 as const, startHour: 17, endHour: 19 }],
        },
        {
          id: "fp-1t3-c2", name: "1T3 (C2)", professor: "Alfonso Maria De Bengoa Diaz, Daniel Mateos Garcia, Jose Enrique Sanchez Lopez", professors: ["Alfonso Maria De Bengoa Diaz","Daniel Mateos Garcia","Jose Enrique Sanchez Lopez"], type: "theory",
          sessions: [{ day: 2 as const, startHour: 17, endHour: 19 }, { day: 4 as const, startHour: 15, endHour: 17 }],
        },
      ],
    },
    {
      id: "ffi", name: "Fundamentos Físicos de la Informática", code: "2060009", credits: 6,
      course: 1, semester: "C1", type: "obligatoria",
      groups: [
        {
          id: "ffi-1t1-c1", name: "1T1 (C1)", professor: "Jose Luis Mas Balbuena, Niurka Rodriguez Quintero, Triana Czermak Alvarez", professors: ["Jose Luis Mas Balbuena","Niurka Rodriguez Quintero","Triana Czermak Alvarez"], type: "theory",
          sessions: [{ day: 0 as const, startHour: 8, endHour: 10 }, { day: 0 as const, startHour: 12, endHour: 14 }, { day: 1 as const, startHour: 10, endHour: 12 }],
        },
        {
          id: "ffi-1t2-c1", name: "1T2 (C1)", professor: "Alejandro Martinez Ros, Jose Luis Mas Balbuena, Niurka Rodriguez Quintero", professors: ["Alejandro Martinez Ros","Jose Luis Mas Balbuena","Niurka Rodriguez Quintero"], type: "theory",
          sessions: [{ day: 2 as const, startHour: 8, endHour: 10 }, { day: 4 as const, startHour: 10, endHour: 12 }],
        },
        {
          id: "ffi-1t3-c1", name: "1T3 (C1)", professor: "Victor Lopez Flores, Niurka Rodriguez Quintero, Alejandro Martinez Ros, Raul Rodriguez Berral", professors: ["Victor Lopez Flores","Niurka Rodriguez Quintero","Alejandro Martinez Ros","Raul Rodriguez Berral"], type: "theory",
          sessions: [{ day: 1 as const, startHour: 17, endHour: 19 }, { day: 4 as const, startHour: 15, endHour: 17 }],
        },
      ],
    },
    {
      id: "imd", name: "Introducción a la Matemática Discreta", code: "2060005", credits: 6,
      course: 1, semester: "C1", type: "obligatoria",
      groups: [
        {
          id: "imd-1t1-c1", name: "1T1 (C1)", professor: "Juan Carlos Dana Jimenez, Luisa Maria Camacho Santana", professors: ["Juan Carlos Dana Jimenez","Luisa Maria Camacho Santana"], type: "theory",
          sessions: [{ day: 1 as const, startHour: 8, endHour: 10 }, { day: 3 as const, startHour: 10, endHour: 12 }],
        },
        {
          id: "imd-1t2-c1", name: "1T2 (C1)", professor: "Juan Carlos Dana Jimenez, Luisa Maria Camacho Santana", professors: ["Juan Carlos Dana Jimenez","Luisa Maria Camacho Santana"], type: "theory",
          sessions: [{ day: 1 as const, startHour: 10, endHour: 12 }, { day: 3 as const, startHour: 8, endHour: 10 }],
        },
        {
          id: "imd-1t3-c1", name: "1T3 (C1)", professor: "Maria Magdalena Fernandez Lebron, Amparo Osuna Lucena", professors: ["Maria Magdalena Fernandez Lebron","Amparo Osuna Lucena"], type: "theory",
          sessions: [{ day: 1 as const, startHour: 15, endHour: 17 }, { day: 3 as const, startHour: 17, endHour: 19 }],
        },
      ],
    },
    {
      id: "adda", name: "Análisis y Diseño de Datos y Algoritmos", code: "2060010", credits: 12,
      course: 2, semester: "A", type: "obligatoria",
      groups: [
        {
          id: "adda-2t1-c1", name: "2T1 (C1)", professor: "Irene Barba Rodriguez, Antonio Manuel Gutierrez Fernandez, Diana Borrego Nuñez, Juan Alberto Gallardo Gomez, Javier Jesus Gutierrez Rodriguez, Jose Enrique Sanchez Lopez, Francisco Javier Ferrer Troyano, Francisco Fernando De La Rosa Troyano", professors: ["Irene Barba Rodriguez","Antonio Manuel Gutierrez Fernandez","Diana Borrego Nuñez","Juan Alberto Gallardo Gomez","Javier Jesus Gutierrez Rodriguez","Jose Enrique Sanchez Lopez","Francisco Javier Ferrer Troyano","Francisco Fernando De La Rosa Troyano"], type: "theory",
          sessions: [{ day: 0 as const, startHour: 8, endHour: 10 }, { day: 2 as const, startHour: 10, endHour: 12 }],
        },
        {
          id: "adda-2t1-c2", name: "2T1 (C2)", professor: "Irene Barba Rodriguez, Antonio Manuel Gutierrez Fernandez, Diana Borrego Nuñez, Juan Alberto Gallardo Gomez, Javier Jesus Gutierrez Rodriguez, Jose Enrique Sanchez Lopez, Francisco Javier Ferrer Troyano, Francisco Fernando De La Rosa Troyano", professors: ["Irene Barba Rodriguez","Antonio Manuel Gutierrez Fernandez","Diana Borrego Nuñez","Juan Alberto Gallardo Gomez","Javier Jesus Gutierrez Rodriguez","Jose Enrique Sanchez Lopez","Francisco Javier Ferrer Troyano","Francisco Fernando De La Rosa Troyano"], type: "theory",
          sessions: [{ day: 0 as const, startHour: 12, endHour: 14 }, { day: 2 as const, startHour: 10, endHour: 12 }],
        },
        {
          id: "adda-2t2-c1", name: "2T2 (C1)", professor: "Rafael Ceballos Guerrero, Maria Del Mar Martinez Ballesteros, Irene Barba Rodriguez, Antonio Manuel Gutierrez Fernandez, Diana Borrego Nuñez, Jose Enrique Sanchez Lopez", professors: ["Rafael Ceballos Guerrero","Maria Del Mar Martinez Ballesteros","Irene Barba Rodriguez","Antonio Manuel Gutierrez Fernandez","Diana Borrego Nuñez","Jose Enrique Sanchez Lopez"], type: "theory",
          sessions: [{ day: 1 as const, startHour: 12, endHour: 14 }, { day: 3 as const, startHour: 10, endHour: 12 }],
        },
        {
          id: "adda-2t2-c2", name: "2T2 (C2)", professor: "Rafael Ceballos Guerrero, Maria Del Mar Martinez Ballesteros, Irene Barba Rodriguez, Antonio Manuel Gutierrez Fernandez, Diana Borrego Nuñez, Jose Enrique Sanchez Lopez", professors: ["Rafael Ceballos Guerrero","Maria Del Mar Martinez Ballesteros","Irene Barba Rodriguez","Antonio Manuel Gutierrez Fernandez","Diana Borrego Nuñez","Jose Enrique Sanchez Lopez"], type: "theory",
          sessions: [{ day: 1 as const, startHour: 12, endHour: 14 }, { day: 2 as const, startHour: 12, endHour: 14 }],
        },
        {
          id: "adda-2t3-c1", name: "2T3 (C1)", professor: "Antonio Manuel Gutierrez Fernandez, Javier Jesus Gutierrez Rodriguez, Antonio Martinez Rojas, Jose Enrique Sanchez Lopez, Francisco Javier Ferrer Troyano, Adrian Romero Flores", professors: ["Antonio Manuel Gutierrez Fernandez","Javier Jesus Gutierrez Rodriguez","Antonio Martinez Rojas","Jose Enrique Sanchez Lopez","Francisco Javier Ferrer Troyano","Adrian Romero Flores"], type: "theory",
          sessions: [{ day: 0 as const, startHour: 15, endHour: 17 }, { day: 2 as const, startHour: 17, endHour: 19 }],
        },
        {
          id: "adda-2t3-c2", name: "2T3 (C2)", professor: "Antonio Manuel Gutierrez Fernandez, Javier Jesus Gutierrez Rodriguez, Antonio Martinez Rojas, Jose Enrique Sanchez Lopez, Francisco Javier Ferrer Troyano, Adrian Romero Flores", professors: ["Antonio Manuel Gutierrez Fernandez","Javier Jesus Gutierrez Rodriguez","Antonio Martinez Rojas","Jose Enrique Sanchez Lopez","Francisco Javier Ferrer Troyano","Adrian Romero Flores"], type: "theory",
          sessions: [{ day: 0 as const, startHour: 17, endHour: 19 }, { day: 2 as const, startHour: 17, endHour: 19 }],
        },
      ],
    },
    {
      id: "ac", name: "Arquitectura de Computadores", code: "2060015", credits: 6,
      course: 2, semester: "C2", type: "obligatoria",
      groups: [
        {
          id: "ac-2t1-c2", name: "2T1 (C2)", professor: "Elena Cerezuela Escudero, Antonio Abad Civit Balcells, Maria Lourdes Miro Amarante, Manuel Rivas Perez", professors: ["Elena Cerezuela Escudero","Antonio Abad Civit Balcells","Maria Lourdes Miro Amarante","Manuel Rivas Perez"], type: "theory",
          sessions: [{ day: 0 as const, startHour: 10, endHour: 12 }, { day: 3 as const, startHour: 8, endHour: 10 }, { day: 3 as const, startHour: 12, endHour: 14 }, { day: 4 as const, startHour: 8, endHour: 10 }],
        },
        {
          id: "ac-2t2-c2", name: "2T2 (C2)", professor: "Manuel Jesus Dominguez Morales, Manuel Rivas Perez, Maria Lourdes Miro Amarante, Francisco Luna Perejon, Lourdes Duran Lopez", professors: ["Manuel Jesus Dominguez Morales","Manuel Rivas Perez","Maria Lourdes Miro Amarante","Francisco Luna Perejon","Lourdes Duran Lopez"], type: "theory",
          sessions: [{ day: 0 as const, startHour: 8, endHour: 10 }, { day: 4 as const, startHour: 8, endHour: 10 }, { day: 4 as const, startHour: 10, endHour: 12 }],
        },
        {
          id: "ac-2t3-c2", name: "2T3 (C2)", professor: "Javier Civit Masot, Lourdes Duran Lopez, Elena Cerezuela Escudero", professors: ["Javier Civit Masot","Lourdes Duran Lopez","Elena Cerezuela Escudero"], type: "theory",
          sessions: [{ day: 0 as const, startHour: 15, endHour: 17 }, { day: 3 as const, startHour: 15, endHour: 17 }, { day: 3 as const, startHour: 19, endHour: 21 }],
        },
      ],
    },
    {
      id: "ar", name: "Arquitectura de Redes", code: "2060016", credits: 6,
      course: 2, semester: "C2", type: "optativa",
      groups: [
        {
          id: "ar-2t1-c2", name: "2T1 (C2)", professor: "Alejandro Casado Galan, Jorge Ropero Rodriguez, Paula Heimberg González, German Cano Quiveu", professors: ["Alejandro Casado Galan","Jorge Ropero Rodriguez","Paula Heimberg González","German Cano Quiveu"], type: "theory",
          sessions: [{ day: 0 as const, startHour: 8, endHour: 10 }, { day: 2 as const, startHour: 12, endHour: 14 }, { day: 4 as const, startHour: 12, endHour: 14 }],
        },
        {
          id: "ar-2t2-c2", name: "2T2 (C2)", professor: "Enrique Dorronzoro Zubiete, Alejandro Casado Galan", professors: ["Enrique Dorronzoro Zubiete","Alejandro Casado Galan"], type: "theory",
          sessions: [{ day: 1 as const, startHour: 8, endHour: 10 }, { day: 2 as const, startHour: 8, endHour: 10 }, { day: 3 as const, startHour: 8, endHour: 10 }, { day: 3 as const, startHour: 10, endHour: 12 }],
        },
        {
          id: "ar-2t3-c2", name: "2T3 (C2)", professor: "Julian Viejo Cortes, Clara Lebrato Vazquez, German Cano Quiveu", professors: ["Julian Viejo Cortes","Clara Lebrato Vazquez","German Cano Quiveu"], type: "theory",
          sessions: [{ day: 2 as const, startHour: 15, endHour: 17 }, { day: 2 as const, startHour: 19, endHour: 21 }, { day: 4 as const, startHour: 15, endHour: 17 }],
        },
      ],
    },
    {
      id: "iissi1", name: "Introducción a la Ingeniería del Software y los Sistemas de Información I", code: "2060054", credits: 6,
      course: 2, semester: "C1", type: "obligatoria",
      groups: [
        {
          id: "iissi1-2t1-c1", name: "2T1 (C1)", professor: "Maria Margarita Cruz Risco, David Ruiz Cortes", professors: ["Maria Margarita Cruz Risco","David Ruiz Cortes"], type: "theory",
          sessions: [{ day: 1 as const, startHour: 8, endHour: 10 }, { day: 3 as const, startHour: 10, endHour: 12 }],
        },
        {
          id: "iissi1-2t2-c1", name: "2T2 (C1)", professor: "David Ruiz Cortes, Inmaculada Concepcion Hernandez Salmeron, Maria Margarita Cruz Risco", professors: ["David Ruiz Cortes","Inmaculada Concepcion Hernandez Salmeron","Maria Margarita Cruz Risco"], type: "theory",
          sessions: [{ day: 1 as const, startHour: 10, endHour: 12 }, { day: 3 as const, startHour: 12, endHour: 14 }],
        },
        {
          id: "iissi1-2t3-c1", name: "2T3 (C1)", professor: "David Ruiz Cortes, Maria Margarita Cruz Risco", professors: ["David Ruiz Cortes","Maria Margarita Cruz Risco"], type: "theory",
          sessions: [{ day: 1 as const, startHour: 15, endHour: 17 }, { day: 3 as const, startHour: 17, endHour: 19 }],
        },
      ],
    },
    {
      id: "iissi2", name: "Introducción a la Ingeniería del Software y los Sistemas de Información II", code: "2060055", credits: 6,
      course: 2, semester: "C2", type: "obligatoria",
      groups: [
        {
          id: "iissi2-2t1-c2", name: "2T1 (C2)", professor: "Maria Margarita Cruz Risco, Carlos Arevalo Maldonado, Jose Calderon Valdivia", professors: ["Maria Margarita Cruz Risco","Carlos Arevalo Maldonado","Jose Calderon Valdivia"], type: "theory",
          sessions: [{ day: 1 as const, startHour: 8, endHour: 10 }, { day: 3 as const, startHour: 10, endHour: 12 }],
        },
        {
          id: "iissi2-2t2-c2", name: "2T2 (C2)", professor: "Inmaculada Concepcion Hernandez Salmeron, David Ruiz Cortes, Jose Calderon Valdivia, Carlos Arevalo Maldonado", professors: ["Inmaculada Concepcion Hernandez Salmeron","David Ruiz Cortes","Jose Calderon Valdivia","Carlos Arevalo Maldonado"], type: "theory",
          sessions: [{ day: 2 as const, startHour: 10, endHour: 12 }, { day: 3 as const, startHour: 12, endHour: 14 }],
        },
        {
          id: "iissi2-2t3-c2", name: "2T3 (C2)", professor: "Carlos Arevalo Maldonado, Daniel Ayala Hernandez, Diego Manuel Galloso Fernandez, Inmaculada Concepcion Hernandez Salmeron, Aitor Rodriguez Dueñas", professors: ["Carlos Arevalo Maldonado","Daniel Ayala Hernandez","Diego Manuel Galloso Fernandez","Inmaculada Concepcion Hernandez Salmeron","Aitor Rodriguez Dueñas"], type: "theory",
          sessions: [{ day: 1 as const, startHour: 15, endHour: 17 }, { day: 3 as const, startHour: 17, endHour: 19 }],
        },
      ],
    },
    {
      id: "li", name: "Lógica Informática", code: "2060012", credits: 6,
      course: 2, semester: "C1", type: "optativa",
      groups: [
        {
          id: "li-2t1-c1", name: "2T1 (C1)", professor: "Andres Cordon Franco", professors: ["Andres Cordon Franco"], type: "theory",
          sessions: [{ day: 2 as const, startHour: 8, endHour: 10 }, { day: 4 as const, startHour: 10, endHour: 12 }],
        },
        {
          id: "li-2t2-c1", name: "2T2 (C1)", professor: "Joaquin Borrego Diaz", professors: ["Joaquin Borrego Diaz"], type: "theory",
          sessions: [{ day: 2 as const, startHour: 8, endHour: 10 }, { day: 4 as const, startHour: 8, endHour: 10 }],
        },
        {
          id: "li-2t3-c1", name: "2T3 (C1)", professor: "Fernando Sancho Caparrini", professors: ["Fernando Sancho Caparrini"], type: "theory",
          sessions: [{ day: 2 as const, startHour: 15, endHour: 17 }, { day: 4 as const, startHour: 17, endHour: 19 }],
        },
      ],
    },
    {
      id: "md", name: "Matemática Discreta", code: "2060013", credits: 6,
      course: 2, semester: "C1", type: "obligatoria",
      groups: [
        {
          id: "md-2t1-c1", name: "2T1 (C1)", professor: "Yolanda De La Riva Moreno, Alberto Cerezo Cid", professors: ["Yolanda De La Riva Moreno","Alberto Cerezo Cid"], type: "theory",
          sessions: [{ day: 1 as const, startHour: 10, endHour: 12 }, { day: 4 as const, startHour: 8, endHour: 10 }, { day: 4 as const, startHour: 12, endHour: 14 }],
        },
        {
          id: "md-2t2-c1", name: "2T2 (C1)", professor: "Yolanda De La Riva Moreno, Alberto Cerezo Cid", professors: ["Yolanda De La Riva Moreno","Alberto Cerezo Cid"], type: "theory",
          sessions: [{ day: 0 as const, startHour: 12, endHour: 14 }, { day: 4 as const, startHour: 10, endHour: 12 }, { day: 4 as const, startHour: 12, endHour: 14 }],
        },
        {
          id: "md-2t3-c1", name: "2T3 (C1)", professor: "Emmanuel Jean Briand, Alberto Cerezo Cid", professors: ["Emmanuel Jean Briand","Alberto Cerezo Cid"], type: "theory",
          sessions: [{ day: 1 as const, startHour: 17, endHour: 19 }, { day: 4 as const, startHour: 15, endHour: 17 }],
        },
      ],
    },
    {
      id: "rc", name: "Redes de Computadores", code: "2060014", credits: 6,
      course: 2, semester: "C1", type: "obligatoria",
      groups: [
        {
          id: "rc-2t1-c1", name: "2T1 (C1)", professor: "Jorge Ropero Rodriguez, Jose Manuel Bravo Garcia, Julian Viejo Cortes, Eduardo Hidalgo Fort, Paula Navarro Gonzalez", professors: ["Jorge Ropero Rodriguez","Jose Manuel Bravo Garcia","Julian Viejo Cortes","Eduardo Hidalgo Fort","Paula Navarro Gonzalez"], type: "theory",
          sessions: [{ day: 0 as const, startHour: 10, endHour: 12 }, { day: 3 as const, startHour: 8, endHour: 10 }, { day: 3 as const, startHour: 12, endHour: 14 }],
        },
        {
          id: "rc-2t2-c1", name: "2T2 (C1)", professor: "Alejandro Carrasco Muñoz, Julian Viejo Cortes, Jose Manuel Bravo Garcia, Eduardo Hidalgo Fort, Paula Navarro Gonzalez", professors: ["Alejandro Carrasco Muñoz","Julian Viejo Cortes","Jose Manuel Bravo Garcia","Eduardo Hidalgo Fort","Paula Navarro Gonzalez"], type: "theory",
          sessions: [{ day: 1 as const, startHour: 8, endHour: 10 }, { day: 2 as const, startHour: 10, endHour: 12 }, { day: 2 as const, startHour: 12, endHour: 14 }, { day: 3 as const, startHour: 8, endHour: 10 }],
        },
        {
          id: "rc-2t3-c1", name: "2T3 (C1)", professor: "Julian Viejo Cortes, Adrian Estrada Perez, Samuel Dominguez Cid", professors: ["Julian Viejo Cortes","Adrian Estrada Perez","Samuel Dominguez Cid"], type: "theory",
          sessions: [{ day: 0 as const, startHour: 17, endHour: 19 }, { day: 3 as const, startHour: 15, endHour: 17 }, { day: 3 as const, startHour: 19, endHour: 21 }],
        },
      ],
    },
    {
      id: "so", name: "Sistemas Operativos", code: "2060017", credits: 6,
      course: 2, semester: "C2", type: "obligatoria",
      groups: [
        {
          id: "so-2t1-c2", name: "2T1 (C2)", professor: "David Gutierrez Aviles, Jose Antonio Perez Castellanos", professors: ["David Gutierrez Aviles","Jose Antonio Perez Castellanos"], type: "theory",
          sessions: [{ day: 1 as const, startHour: 10, endHour: 12 }, { day: 4 as const, startHour: 10, endHour: 12 }],
        },
        {
          id: "so-2t2-c2", name: "2T2 (C2)", professor: "David Romero Organvidez, David Gutierrez Aviles", professors: ["David Romero Organvidez","David Gutierrez Aviles"], type: "theory",
          sessions: [{ day: 0 as const, startHour: 10, endHour: 12 }, { day: 4 as const, startHour: 12, endHour: 14 }],
        },
        {
          id: "so-2t3-c2", name: "2T3 (C2)", professor: "Maria Elena Molina Reyes, Leticia Morales Trujillo, David Romero Organvidez", professors: ["Maria Elena Molina Reyes","Leticia Morales Trujillo","David Romero Organvidez"], type: "theory",
          sessions: [{ day: 1 as const, startHour: 17, endHour: 19 }, { day: 4 as const, startHour: 17, endHour: 19 }],
        },
      ],
    },
    {
      id: "aia", name: "Ampliación de Inteligencia Artificial", code: "2060025", credits: 6,
      course: 3, semester: "C2", type: "optativa",
      groups: [
        {
          id: "aia-3t1-c2", name: "3T1 (C2)", professor: "Jose Luis Ruiz Reina, Francisco Eduardo Sanchez Karhunen", professors: ["Jose Luis Ruiz Reina","Francisco Eduardo Sanchez Karhunen"], type: "theory",
          sessions: [{ day: 2 as const, startHour: 10, endHour: 12 }, { day: 3 as const, startHour: 15, endHour: 17 }],
        },
      ],
    },
    {
      id: "asd", name: "Arquitectura de Sistemas Distribuidos", code: "2060026", credits: 6,
      course: 3, semester: "C2", type: "optativa",
      groups: [
        {
          id: "asd-3t1-c2", name: "3T1 (C2)", professor: "Luis Muñoz Saavedra, Jose Luis Sevillano Ramos, Maria Jose Moron Fernandez", professors: ["Luis Muñoz Saavedra","Jose Luis Sevillano Ramos","Maria Jose Moron Fernandez"], type: "theory",
          sessions: [{ day: 0 as const, startHour: 10, endHour: 12 }, { day: 1 as const, startHour: 8, endHour: 10 }],
        },
      ],
    },
    {
      id: "cimsi", name: "Configuración, Implementación y Mantenimiento de Sistemas Informáticos", code: "2060018", credits: 6,
      course: 3, semester: "C1", type: "optativa",
      groups: [
        {
          id: "cimsi-3t1-c1", name: "3T1 (C1)", professor: "Daniel Cascado Caballero", professors: ["Daniel Cascado Caballero"], type: "theory",
          sessions: [{ day: 1 as const, startHour: 10, endHour: 12 }, { day: 3 as const, startHour: 10, endHour: 12 }],
        },
      ],
    },
    {
      id: "gsi", name: "Gestión de Sistemas de Información", code: "2060019", credits: 6,
      course: 3, semester: "C1", type: "optativa",
      groups: [
        {
          id: "gsi-3t1-c1", name: "3T1 (C1)", professor: "Joaquin Peña Siles", professors: ["Joaquin Peña Siles"], type: "theory",
          sessions: [{ day: 2 as const, startHour: 10, endHour: 12 }, { day: 3 as const, startHour: 19, endHour: 21 }],
        },
      ],
    },
    {
      id: "gee", name: "Gestión y Estrategia Empresarial", code: "2060020", credits: 6,
      course: 3, semester: "C1", type: "optativa",
      groups: [
        {
          id: "gee-3t1-c1", name: "3T1 (C1)", professor: "Mario Canivell Rodriguez, Carlos Manuel Gomez Alvarez, Jose Carlos Molina Gomez", professors: ["Mario Canivell Rodriguez","Carlos Manuel Gomez Alvarez","Jose Carlos Molina Gomez"], type: "theory",
          sessions: [{ day: 0 as const, startHour: 17, endHour: 19 }, { day: 4 as const, startHour: 15, endHour: 17 }],
        },
      ],
    },
    {
      id: "ia", name: "Inteligencia Artificial", code: "2060021", credits: 6,
      course: 3, semester: "C1", type: "obligatoria",
      groups: [
        {
          id: "ia-3t1-c1", name: "3T1 (C1)", professor: "Maria Carmen Graciani Diaz, Andres Nicolas Uranga Limon", professors: ["Maria Carmen Graciani Diaz","Andres Nicolas Uranga Limon"], type: "theory",
          sessions: [{ day: 1 as const, startHour: 12, endHour: 14 }, { day: 3 as const, startHour: 12, endHour: 14 }],
        },
      ],
    },
    {
      id: "masi", name: "Matemática Aplicada a Sistemas de Información", code: "2060027", credits: 6,
      course: 3, semester: "C2", type: "optativa",
      groups: [
        {
          id: "masi-3t1-c2", name: "3T1 (C2)", professor: "Maria Cruz Lopez De Los Mozos Martin, Jose Maria Ucha Enriquez", professors: ["Maria Cruz Lopez De Los Mozos Martin","Jose Maria Ucha Enriquez"], type: "theory",
          sessions: [{ day: 2 as const, startHour: 12, endHour: 14 }, { day: 3 as const, startHour: 8, endHour: 10 }],
        },
      ],
    },
    {
      id: "pl", name: "Procesadores de Lenguajes", code: "2060022", credits: 6,
      course: 3, semester: "C1", type: "optativa",
      groups: [
        {
          id: "pl-3t1-c1", name: "3T1 (C1)", professor: "Francisco Jose Galan Morillo", professors: ["Francisco Jose Galan Morillo"], type: "theory",
          sessions: [{ day: 2 as const, startHour: 8, endHour: 10 }],
        },
      ],
    },
    {
      id: "pd", name: "Programación Declarativa", code: "2060023", credits: 6,
      course: 3, semester: "C1", type: "optativa",
      groups: [
        {
          id: "pd-3t1-c1", name: "3T1 (C1)", professor: "David Solis Martin, Antonio Ramirez De Arellano Marrero", professors: ["David Solis Martin","Antonio Ramirez De Arellano Marrero"], type: "theory",
          sessions: [{ day: 1 as const, startHour: 17, endHour: 19 }, { day: 3 as const, startHour: 15, endHour: 17 }],
        },
      ],
    },
    {
      id: "sie", name: "Sistemas de Información Empresariales", code: "2060028", credits: 6,
      course: 3, semester: "C2", type: "optativa",
      groups: [
        {
          id: "sie-3t1-c2", name: "3T1 (C2)", professor: "Fernando Enriquez De Salamanca Ros", professors: ["Fernando Enriquez De Salamanca Ros"], type: "theory",
          sessions: [{ day: 1 as const, startHour: 10, endHour: 12 }, { day: 3 as const, startHour: 10, endHour: 12 }],
        },
      ],
    },
    {
      id: "si", name: "Sistemas Inteligentes", code: "2060029", credits: 6,
      course: 3, semester: "C2", type: "optativa",
      groups: [
        {
          id: "si-3t1-c2", name: "3T1 (C2)", professor: "Joaquin Borrego Diaz, Andres Nicolas Uranga Limon", professors: ["Joaquin Borrego Diaz","Andres Nicolas Uranga Limon"], type: "theory",
          sessions: [{ day: 1 as const, startHour: 12, endHour: 14 }, { day: 2 as const, startHour: 8, endHour: 10 }],
        },
      ],
    },
    {
      id: "sos", name: "Sistemas Orientados a Servicios", code: "2060030", credits: 6,
      course: 3, semester: "C2", type: "optativa",
      groups: [
        {
          id: "sos-3t1-c2", name: "3T1 (C2)", professor: "Pablo Fernandez Montes", professors: ["Pablo Fernandez Montes"], type: "theory",
          sessions: [{ day: 4 as const, startHour: 10, endHour: 12 }],
        },
      ],
    },
    {
      id: "tai", name: "Tecnologías Avanzadas de la Información", code: "2060024", credits: 6,
      course: 3, semester: "C1", type: "optativa",
      groups: [
        {
          id: "tai-3t1-c1", name: "3T1 (C1)", professor: "German Cano Quiveu, Paulino Ruiz De Clavijo Vazquez, Noelia Navarro Moreno", professors: ["German Cano Quiveu","Paulino Ruiz De Clavijo Vazquez","Noelia Navarro Moreno"], type: "theory",
          sessions: [{ day: 2 as const, startHour: 15, endHour: 17 }, { day: 2 as const, startHour: 17, endHour: 19 }, { day: 2 as const, startHour: 19, endHour: 21 }, { day: 4 as const, startHour: 8, endHour: 10 }, { day: 4 as const, startHour: 12, endHour: 14 }],
        },
      ],
    },
    {
      id: "aii", name: "Acceso Inteligente a la Información", code: "2060032", credits: 6,
      course: 4, semester: "C2", type: "optativa",
      groups: [
        {
          id: "aii-4t1-c2", name: "4T1 (C2)", professor: "Vicente Carrillo Montero", professors: ["Vicente Carrillo Montero"], type: "theory",
          sessions: [{ day: 1 as const, startHour: 10, endHour: 12 }, { day: 4 as const, startHour: 8, endHour: 10 }, { day: 4 as const, startHour: 12, endHour: 14 }],
        },
      ],
    },
    {
      id: "asi", name: "Administración de Sistemas de Información", code: "2060033", credits: 6,
      course: 4, semester: "C1", type: "optativa",
      groups: [
        {
          id: "asi-4t1-c1", name: "4T1 (C1)", professor: "Jaime Benjumea Mondejar", professors: ["Jaime Benjumea Mondejar"], type: "theory",
          sessions: [{ day: 1 as const, startHour: 15, endHour: 17 }, { day: 3 as const, startHour: 15, endHour: 17 }, { day: 3 as const, startHour: 17, endHour: 19 }],
        },
      ],
    },
    {
      id: "asc", name: "Aplicaciones de Soft Computing", code: "2060044", credits: 6,
      course: 4, semester: "C2", type: "optativa",
      groups: [
        {
          id: "asc-4t1-c2", name: "4T1 (C2)", professor: "Maria Iluminada Baturone Castillo", professors: ["Maria Iluminada Baturone Castillo"], type: "theory",
          sessions: [{ day: 0 as const, startHour: 12, endHour: 14 }, { day: 3 as const, startHour: 8, endHour: 10 }],
        },
      ],
    },
    {
      id: "cm", name: "Computación Móvil", code: "2060045", credits: 6,
      course: 4, semester: "C2", type: "optativa",
      groups: [
        {
          id: "cm-4t1-c2", name: "4T1 (C2)", professor: "Rafael Paz Vicente", professors: ["Rafael Paz Vicente"], type: "theory",
          sessions: [{ day: 0 as const, startHour: 15, endHour: 17 }, { day: 1 as const, startHour: 17, endHour: 19 }, { day: 2 as const, startHour: 15, endHour: 17 }, { day: 2 as const, startHour: 19, endHour: 21 }],
        },
      ],
    },
    {
      id: "crip", name: "Criptografía", code: "2060046", credits: 6,
      course: 4, semester: "C2", type: "optativa",
      groups: [
        {
          id: "crip-4t1-c2", name: "4T1 (C2)", professor: "Victor Alvarez Solano, Felix Gudiel Rodriguez", professors: ["Victor Alvarez Solano","Felix Gudiel Rodriguez"], type: "theory",
          sessions: [{ day: 2 as const, startHour: 12, endHour: 14 }, { day: 4 as const, startHour: 10, endHour: 12 }],
        },
      ],
    },
    {
      id: "ecomp", name: "Estadística Computacional", code: "2060047", credits: 6,
      course: 4, semester: "C2", type: "optativa",
      groups: [
        {
          id: "ecomp-4t1-c2", name: "4T1 (C2)", professor: "Maria De Los Remedios Sillero Denamiel", professors: ["Maria De Los Remedios Sillero Denamiel"], type: "theory",
          sessions: [{ day: 0 as const, startHour: 17, endHour: 19 }, { day: 2 as const, startHour: 17, endHour: 19 }],
        },
      ],
    },
    {
      id: "gp", name: "Gestión de la Producción", code: "2060048", credits: 6,
      course: 4, semester: "C2", type: "optativa",
      groups: [
        {
          id: "gp-4t1-c2", name: "4T1 (C2)", professor: "Jose Manuel Garcia Sanchez, Ramon Piedra De La Cuadra", professors: ["Jose Manuel Garcia Sanchez","Ramon Piedra De La Cuadra"], type: "theory",
          sessions: [{ day: 0 as const, startHour: 10, endHour: 12 }, { day: 2 as const, startHour: 8, endHour: 10 }],
        },
      ],
    },
    {
      id: "gps", name: "Gestión de Procesos y Servicios", code: "2060034", credits: 6,
      course: 4, semester: "C1", type: "optativa",
      groups: [
        {
          id: "gps-4t1-c1", name: "4T1 (C1)", professor: "Cristina Cabanillas Macias, Irene Bedilia Estrada Torres, Adela Del Rio Ortega", professors: ["Cristina Cabanillas Macias","Irene Bedilia Estrada Torres","Adela Del Rio Ortega"], type: "theory",
          sessions: [{ day: 1 as const, startHour: 10, endHour: 12 }, { day: 4 as const, startHour: 12, endHour: 14 }],
        },
      ],
    },
    {
      id: "isi", name: "Infraestructura de Sistemas de Información", code: "2060035", credits: 6,
      course: 4, semester: "C1", type: "optativa",
      groups: [
        {
          id: "isi-4t1-c1", name: "4T1 (C1)", professor: "Enrique Ostua Aranguena", professors: ["Enrique Ostua Aranguena"], type: "theory",
          sessions: [{ day: 2 as const, startHour: 10, endHour: 12 }, { day: 4 as const, startHour: 8, endHour: 10 }],
        },
      ],
    },
    {
      id: "ie", name: "Inteligencia Empresarial", code: "2060049", credits: 6,
      course: 4, semester: "C2", type: "optativa",
      groups: [
        {
          id: "ie-4t1-c2", name: "4T1 (C2)", professor: "Francisco Javier Ortega Rodriguez, Aitor Rodriguez Dueñas, Beatriz Pontes Balanza", professors: ["Francisco Javier Ortega Rodriguez","Aitor Rodriguez Dueñas","Beatriz Pontes Balanza"], type: "theory",
          sessions: [{ day: 1 as const, startHour: 12, endHour: 14 }, { day: 2 as const, startHour: 10, endHour: 12 }],
        },
      ],
    },
    {
      id: "ipo", name: "Interacción Persona-ordenador", code: "2060037", credits: 6,
      course: 4, semester: "C1", type: "optativa",
      groups: [
        {
          id: "ipo-4t1-c1", name: "4T1 (C1)", professor: "Victor Jesus Diaz Madrigal, Jose Mariano Gonzalez Romano", professors: ["Victor Jesus Diaz Madrigal","Jose Mariano Gonzalez Romano"], type: "theory",
          sessions: [{ day: 0 as const, startHour: 19, endHour: 21 }, { day: 2 as const, startHour: 17, endHour: 19 }],
        },
      ],
    },
    {
      id: "mati", name: "Matemática Aplicada a Tecnologías de la Información", code: "2060038", credits: 6,
      course: 4, semester: "C1", type: "optativa",
      groups: [
        {
          id: "mati-4t1-c1", name: "4T1 (C1)", professor: "Maria Nieves Atienza Martinez, Pedro Gomez De Terreros Oramas, Jose Ramon Portillo Fernandez", professors: ["Maria Nieves Atienza Martinez","Pedro Gomez De Terreros Oramas","Jose Ramon Portillo Fernandez"], type: "theory",
          sessions: [{ day: 4 as const, startHour: 15, endHour: 17 }],
        },
      ],
    },
    {
      id: "mc", name: "Matemáticas para la Computación", code: "2060039", credits: 6,
      course: 4, semester: "C1", type: "optativa",
      groups: [
        {
          id: "mc-4t1-c1", name: "4T1 (C1)", professor: "Juan Vicente Gutierrez Santacreu, Maria Cruz Lopez De Los Mozos Martin", professors: ["Juan Vicente Gutierrez Santacreu","Maria Cruz Lopez De Los Mozos Martin"], type: "theory",
          sessions: [{ day: 0 as const, startHour: 8, endHour: 10 }, { day: 3 as const, startHour: 12, endHour: 14 }],
        },
      ],
    },
    {
      id: "marsi", name: "Modelado y Análisis de Requisitos en Sistemas de Información", code: "2060050", credits: 6,
      course: 4, semester: "C2", type: "optativa",
      groups: [
        {
          id: "marsi-4t1-c2", name: "4T1 (C2)", professor: "Francisco Jose Dominguez Mayo, Miguel Angel Olivero Gonzalez", professors: ["Francisco Jose Dominguez Mayo","Miguel Angel Olivero Gonzalez"], type: "theory",
          sessions: [{ day: 1 as const, startHour: 8, endHour: 10 }, { day: 3 as const, startHour: 10, endHour: 12 }],
        },
      ],
    },
    {
      id: "mcc", name: "Modelos de Computación y Complejidad", code: "2060051", credits: 6,
      course: 4, semester: "C2", type: "optativa",
      groups: [
        {
          id: "mcc-4t1-c2", name: "4T1 (C2)", professor: "Andres Cordon Franco", professors: ["Andres Cordon Franco"], type: "theory",
          sessions: [{ day: 0 as const, startHour: 8, endHour: 10 }, { day: 3 as const, startHour: 12, endHour: 14 }],
        },
      ],
    },
    {
      id: "pgpi", name: "Planificación y Gestión de Proyectos Informáticos", code: "2060040", credits: 6,
      course: 4, semester: "C1", type: "obligatoria",
      groups: [
        {
          id: "pgpi-4t1-c1", name: "4T1 (C1)", professor: "Victor Alvarez Solano, Jose Andres Armario Sampalo, Felix Gudiel Rodriguez", professors: ["Victor Alvarez Solano","Jose Andres Armario Sampalo","Felix Gudiel Rodriguez"], type: "theory",
          sessions: [{ day: 1 as const, startHour: 12, endHour: 14 }, { day: 3 as const, startHour: 8, endHour: 10 }],
        },
      ],
    },
    {
      id: "pid", name: "Procesamiento de Imágenes Digitales", code: "2060041", credits: 6,
      course: 4, semester: "C1", type: "optativa",
      groups: [
        {
          id: "pid-4t1-c1", name: "4T1 (C1)", professor: "Elena Camacho Aguilar, Maria Jose Jimenez Rodriguez, Belen Medrano Garfia", professors: ["Elena Camacho Aguilar","Maria Jose Jimenez Rodriguez","Belen Medrano Garfia"], type: "theory",
          sessions: [{ day: 2 as const, startHour: 15, endHour: 17 }, { day: 4 as const, startHour: 17, endHour: 19 }],
        },
      ],
    },
    {
      id: "ssii", name: "Seguridad en Sistemas Informáticos y en Internet", code: "2060042", credits: 6,
      course: 4, semester: "C1", type: "optativa",
      groups: [
        {
          id: "ssii-4t1-c1", name: "4T1 (C1)", professor: "Rafael Ceballos Guerrero", professors: ["Rafael Ceballos Guerrero"], type: "theory",
          sessions: [{ day: 1 as const, startHour: 8, endHour: 10 }, { day: 4 as const, startHour: 10, endHour: 12 }],
        },
      ],
    },
    {
      id: "tis", name: "Tecnología, Informática y Sociedad", code: "2060052", credits: 6,
      course: 4, semester: "C2", type: "optativa",
      groups: [
        {
          id: "tis-4t1-c2", name: "4T1 (C2)", professor: "María Gloria Miro Amarante", professors: ["María Gloria Miro Amarante"], type: "theory",
          sessions: [{ day: 1 as const, startHour: 15, endHour: 17 }, { day: 3 as const, startHour: 15, endHour: 17 }, { day: 3 as const, startHour: 17, endHour: 19 }],
        },
      ],
    },
    {
      id: "t", name: "Teledetección", code: "2060043", credits: 6,
      course: 4, semester: "C1", type: "optativa",
      groups: [
        {
          id: "t-4t1-c1", name: "4T1 (C1)", professor: "Juan Antonio Castro Garcia", professors: ["Juan Antonio Castro Garcia"], type: "theory",
          sessions: [{ day: 3 as const, startHour: 10, endHour: 12 }],
        },
      ],
    },
    {
      id: "tfg", name: "Trabajo Fin de Grado", code: "2060053", credits: 12,
      course: 4, semester: "C2", type: "obligatoria",
      groups: [
      ],
    },
  ],
};
