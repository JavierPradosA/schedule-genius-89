import fs from 'node:fs';
import { chromium } from 'playwright';
import { JSDOM } from 'jsdom';

const OUTPUT = 'tmp_etsii_ti_extracted.json';

const COURSES = [
  { course: 1, groups: [1, 2, 3] },
  { course: 2, groups: [1, 2, 3] },
  { course: 3, groups: [1] },
  { course: 4, groups: [1] },
];

const SUBJECTS = {
  AE: { id: 'ae', code: '2060002', name: 'Administración de Empresas', credits: 6, course: 1, semester: 'C2', type: 'obligatoria' },
  ALN: { id: 'aln', code: '2060006', name: 'Álgebra Lineal y Numérica', credits: 6, course: 1, semester: 'C2', type: 'obligatoria' },
  CIN: { id: 'cin', code: '2060003', name: 'Cálculo Infinitesimal y Numérico', credits: 6, course: 1, semester: 'C1', type: 'obligatoria' },
  CED: { id: 'ced', code: '2060004', name: 'Circuitos Electrónicos Digitales', credits: 6, course: 1, semester: 'C1', type: 'obligatoria' },
  EdC: { id: 'edc', code: '2060008', name: 'Estructura de Computadores', credits: 6, course: 1, semester: 'C2', type: 'obligatoria' },
  FP: { id: 'fp', code: '2060001', name: 'Fundamentos de Programación', credits: 12, course: 1, semester: 'A', type: 'obligatoria' },
  FFI: { id: 'ffi', code: '2060009', name: 'Fundamentos Físicos de la Informática', credits: 6, course: 1, semester: 'C1', type: 'obligatoria' },
  IMD: { id: 'imd', code: '2060005', name: 'Introducción a la Matemática Discreta', credits: 6, course: 1, semester: 'C1', type: 'obligatoria' },
  ADDA: { id: 'adda', code: '2060010', name: 'Análisis y Diseño de Datos y Algoritmos', credits: 12, course: 2, semester: 'A', type: 'obligatoria' },
  AC: { id: 'ac', code: '2060015', name: 'Arquitectura de Computadores', credits: 6, course: 2, semester: 'C2', type: 'obligatoria' },
  AR: { id: 'ar', code: '2060016', name: 'Arquitectura de Redes', credits: 6, course: 2, semester: 'C2', type: 'optativa' },
  IISSI1: { id: 'iissi1', code: '2060054', name: 'Introducción a la Ingeniería del Software y los Sistemas de Información I', credits: 6, course: 2, semester: 'C1', type: 'obligatoria' },
  IISSI2: { id: 'iissi2', code: '2060055', name: 'Introducción a la Ingeniería del Software y los Sistemas de Información II', credits: 6, course: 2, semester: 'C2', type: 'obligatoria' },
  LI: { id: 'li', code: '2060012', name: 'Lógica Informática', credits: 6, course: 2, semester: 'C1', type: 'optativa' },
  MD: { id: 'md', code: '2060013', name: 'Matemática Discreta', credits: 6, course: 2, semester: 'C1', type: 'obligatoria' },
  RC: { id: 'rc', code: '2060014', name: 'Redes de Computadores', credits: 6, course: 2, semester: 'C1', type: 'obligatoria' },
  SO: { id: 'so', code: '2060017', name: 'Sistemas Operativos', credits: 6, course: 2, semester: 'C2', type: 'obligatoria' },
  AIA: { id: 'aia', code: '2060025', name: 'Ampliación de Inteligencia Artificial', credits: 6, course: 3, semester: 'C2', type: 'optativa' },
  ASD: { id: 'asd', code: '2060026', name: 'Arquitectura de Sistemas Distribuidos', credits: 6, course: 3, semester: 'C2', type: 'optativa' },
  CIMSI: { id: 'cimsi', code: '2060018', name: 'Configuración, Implementación y Mantenimiento de Sistemas Informáticos', credits: 6, course: 3, semester: 'C1', type: 'optativa' },
  GSI: { id: 'gsi', code: '2060019', name: 'Gestión de Sistemas de Información', credits: 6, course: 3, semester: 'C1', type: 'optativa' },
  GEE: { id: 'gee', code: '2060020', name: 'Gestión y Estrategia Empresarial', credits: 6, course: 3, semester: 'C1', type: 'optativa' },
  IA: { id: 'ia', code: '2060021', name: 'Inteligencia Artificial', credits: 6, course: 3, semester: 'C1', type: 'obligatoria' },
  MASI: { id: 'masi', code: '2060027', name: 'Matemática Aplicada a Sistemas de Información', credits: 6, course: 3, semester: 'C2', type: 'optativa' },
  PL: { id: 'pl', code: '2060022', name: 'Procesadores de Lenguajes', credits: 6, course: 3, semester: 'C1', type: 'optativa' },
  PD: { id: 'pd', code: '2060023', name: 'Programación Declarativa', credits: 6, course: 3, semester: 'C1', type: 'optativa' },
  SIE: { id: 'sie', code: '2060028', name: 'Sistemas de Información Empresariales', credits: 6, course: 3, semester: 'C2', type: 'optativa' },
  SI: { id: 'si', code: '2060029', name: 'Sistemas Inteligentes', credits: 6, course: 3, semester: 'C2', type: 'optativa' },
  SOS: { id: 'sos', code: '2060030', name: 'Sistemas Orientados a Servicios', credits: 6, course: 3, semester: 'C2', type: 'optativa' },
  TAI: { id: 'tai', code: '2060024', name: 'Tecnologías Avanzadas de la Información', credits: 6, course: 3, semester: 'C1', type: 'optativa' },
  AII: { id: 'aii', code: '2060032', name: 'Acceso Inteligente a la Información', credits: 6, course: 4, semester: 'C2', type: 'optativa' },
  ASI: { id: 'asi', code: '2060033', name: 'Administración de Sistemas de Información', credits: 6, course: 4, semester: 'C1', type: 'optativa' },
  ASC: { id: 'asc', code: '2060044', name: 'Aplicaciones de Soft Computing', credits: 6, course: 4, semester: 'C2', type: 'optativa' },
  CM: { id: 'cm', code: '2060045', name: 'Computación Móvil', credits: 6, course: 4, semester: 'C2', type: 'optativa' },
  C: { id: 'crip', code: '2060046', name: 'Criptografía', credits: 6, course: 4, semester: 'C2', type: 'optativa' },
  EC: { id: 'ecomp', code: '2060047', name: 'Estadística Computacional', credits: 6, course: 4, semester: 'C2', type: 'optativa' },
  GP: { id: 'gp', code: '2060048', name: 'Gestión de la Producción', credits: 6, course: 4, semester: 'C2', type: 'optativa' },
  GPS: { id: 'gps', code: '2060034', name: 'Gestión de Procesos y Servicios', credits: 6, course: 4, semester: 'C1', type: 'optativa' },
  ISI: { id: 'isi', code: '2060035', name: 'Infraestructura de Sistemas de Información', credits: 6, course: 4, semester: 'C1', type: 'optativa' },
  IE: { id: 'ie', code: '2060049', name: 'Inteligencia Empresarial', credits: 6, course: 4, semester: 'C2', type: 'optativa' },
  IPO: { id: 'ipo', code: '2060037', name: 'Interacción Persona-ordenador', credits: 6, course: 4, semester: 'C1', type: 'optativa' },
  MATI: { id: 'mati', code: '2060038', name: 'Matemática Aplicada a Tecnologías de la Información', credits: 6, course: 4, semester: 'C1', type: 'optativa' },
  MC: { id: 'mc', code: '2060039', name: 'Matemáticas para la Computación', credits: 6, course: 4, semester: 'C1', type: 'optativa' },
  MARSI: { id: 'marsi', code: '2060050', name: 'Modelado y Análisis de Requisitos en Sistemas de Información', credits: 6, course: 4, semester: 'C2', type: 'optativa' },
  MCC: { id: 'mcc', code: '2060051', name: 'Modelos de Computación y Complejidad', credits: 6, course: 4, semester: 'C2', type: 'optativa' },
  PGPI: { id: 'pgpi', code: '2060040', name: 'Planificación y Gestión de Proyectos Informáticos', credits: 6, course: 4, semester: 'C1', type: 'obligatoria' },
  PID: { id: 'pid', code: '2060041', name: 'Procesamiento de Imágenes Digitales', credits: 6, course: 4, semester: 'C1', type: 'optativa' },
  SSII: { id: 'ssii', code: '2060042', name: 'Seguridad en Sistemas Informáticos y en Internet', credits: 6, course: 4, semester: 'C1', type: 'optativa' },
  TIS: { id: 'tis', code: '2060052', name: 'Tecnología, Informática y Sociedad', credits: 6, course: 4, semester: 'C2', type: 'optativa' },
  T: { id: 't', code: '2060043', name: 'Teledetección', credits: 6, course: 4, semester: 'C1', type: 'optativa' },
};

const TIME_SLOTS = {
  '8:30 a 10:20': [8, 10],
  '10:40 a 12:30': [10, 12],
  '12:40 a 14:30': [12, 14],
  '15:30 a 17:20': [15, 17],
  '17:40 a 19:30': [17, 19],
  '19:40 a 21:30': [19, 21],
};

const DAYS = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'];

function cleanSubject(raw) {
  return raw
    .replace(/\*/g, '')
    .replace(/\(\d+\)/g, '')
    .trim();
}

function extractProfessors(value) {
  const match = value.match(/Prof:\s*(.+)$/s);
  if (!match) return [];
  return match[1]
    .split(',')
    .map((name) => name.replace(/\s+/g, ' ').trim())
    .filter(Boolean);
}

function parseTable(table, semester, groupName, collected) {
  const rows = [...table.querySelectorAll('tr')];

  for (const row of rows) {
    const header = row.querySelector('th')?.textContent?.replace(/\s+/g, ' ').trim();
    if (!header || !TIME_SLOTS[header]) continue;

    const [startHour, endHour] = TIME_SLOTS[header];
    const cells = [...row.querySelectorAll('td')];

    for (let day = 0; day < Math.min(cells.length, DAYS.length); day++) {
      const cell = cells[day];
      const activities = [...cell.querySelectorAll('div.asig > span')];

      for (const activity of activities) {
        const acronym = cleanSubject(activity.childNodes[0]?.textContent ?? '');
        const subject = SUBJECTS[acronym];
        if (!subject) {
          continue;
        }

        const key = `${subject.id}:${groupName}:${semester}`;
        if (!collected.has(key)) {
          collected.set(key, {
            subjectId: subject.id,
            group: {
              id: `${subject.id}-${groupName.toLowerCase().replace(/[^a-z0-9]+/g, '-')}-${semester.toLowerCase()}`,
              name: `${groupName} (${semester})`,
              type: 'theory',
              professorSet: new Set(),
              sessionSet: new Set(),
              sessions: [],
            },
          });
        }

        const entry = collected.get(key);
        const labels = [...activity.querySelectorAll('label')];

        for (const label of labels) {
          for (const attr of label.getAttributeNames()) {
            if (!attr.startsWith('data-balloon-')) continue;
            extractProfessors(label.getAttribute(attr) ?? '').forEach((professor) => entry.group.professorSet.add(professor));
          }
        }

        const sessionKey = `${day}-${startHour}-${endHour}`;
        if (!entry.group.sessionSet.has(sessionKey)) {
          entry.group.sessionSet.add(sessionKey);
          entry.group.sessions.push({ day, startHour, endHour });
        }
      }
    }
  }
}

async function loadSchedule(page, course, group) {
  await page.goto('https://www.etsii.us.es/index.php/horarios', { waitUntil: 'domcontentloaded' });
  await page.selectOption('#tit', 'T');
  await page.selectOption('#curso', String(course));
  await page.selectOption('#gruposT', String(group));

  const [popup] = await Promise.all([
    page.waitForEvent('popup'),
    page.locator('form#f_horarios a.btn').click(),
  ]);

  await popup.waitForLoadState('networkidle');
  await popup.locator('input[name=contenido]').waitFor({ state: 'attached', timeout: 15000 });
  const html = await popup.locator('input[name=contenido]').getAttribute('value');
  await popup.close();
  return html ?? '';
}

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage();
const groupsBySubject = new Map();
const rawByGroup = {};

for (const { course, groups } of COURSES) {
  for (const group of groups) {
    const html = await loadSchedule(page, course, group);
    const groupName = `${course}T${group}`;
    rawByGroup[groupName] = html;

    const dom = new JSDOM(html);
    const tables = [...dom.window.document.querySelectorAll('table:not(.referencia)')];

    tables.forEach((table, index) => parseTable(table, index === 0 ? 'C1' : 'C2', groupName, groupsBySubject));
  }
}

await browser.close();

const subjects = Object.entries(SUBJECTS).map(([, subject]) => {
  const groups = [...groupsBySubject.values()]
    .filter((entry) => entry.subjectId === subject.id)
    .map(({ group }) => ({
      id: group.id,
      name: group.name,
      professor: [...group.professorSet].join(', ') || 'Profesorado por determinar',
      type: group.type,
      sessions: group.sessions.sort((a, b) => a.day - b.day || a.startHour - b.startHour),
    }));

  return { ...subject, groups };
});

subjects.push({
  id: 'tfg',
  code: '2060053',
  name: 'Trabajo Fin de Grado',
  credits: 12,
  course: 4,
  semester: 'C2',
  type: 'obligatoria',
  groups: [],
});

fs.writeFileSync(OUTPUT, JSON.stringify({ subjects, rawByGroup }, null, 2), 'utf8');
console.log(`Extraídas ${subjects.length} asignaturas en ${OUTPUT}`);
