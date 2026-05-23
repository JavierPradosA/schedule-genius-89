import fs from 'node:fs';
import { chromium } from 'playwright';
import { JSDOM } from 'jsdom';

const OUTPUT = 'tmp_universidad_sevilla_extracted.json';
const DEGREE_CATALOG_URL = 'https://edwww.us.es/estudiar/que-estudiar/oferta-de-grados';
const ETSII_SCHEDULE_URL = 'https://www.etsii.us.es/index.php/horarios';

const DAYS = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'];
const TIME_SLOTS = {
  '8:30 a 10:20': [8, 10],
  '10:40 a 12:30': [10, 12],
  '12:40 a 14:30': [12, 14],
  '15:30 a 17:20': [15, 17],
  '17:40 a 19:30': [17, 19],
  '19:40 a 21:30': [19, 21],
};

const ETSII_DEGREES = [
  { id: 'us-etsii-c', formValue: 'C', name: 'Grado en Ingeniería Informática - Ingeniería de Computadores' },
  { id: 'us-etsii-s', formValue: 'S', name: 'Grado en Ingeniería Informática - Ingeniería del Software' },
  { id: 'giti', formValue: 'T', name: 'Grado en Ingeniería Informática - Tecnologías Informáticas' },
  { id: 'us-etsii-sa', formValue: 'SA', name: 'Grado en Ingeniería de la Salud' },
  { id: 'us-etsii-in', formValue: 'IN', name: 'Docencia en Inglés - ETSII' },
  { id: 'us-etsii-ia', formValue: 'IA', name: 'Grado en Ingeniería de Inteligencia Artificial' },
];

function slugify(value) {
  return value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');
}

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

async function scrapeDegreeCatalog(page) {
  await page.goto(DEGREE_CATALOG_URL, { waitUntil: 'domcontentloaded', timeout: 30000 });
  const html = await page.content();
  const dom = new JSDOM(html);
  const links = [...dom.window.document.querySelectorAll('a[href]')];
  const degrees = [];
  const seen = new Set();

  for (const link of links) {
    const name = link.textContent?.replace(/\s+/g, ' ').trim();
    if (!name || !/^(Doble\s+)?Grado en /i.test(name)) continue;
    const href = new URL(link.getAttribute('href'), DEGREE_CATALOG_URL).href;
    const id = `us-${slugify(name)}`;
    if (seen.has(id)) continue;
    seen.add(id);
    degrees.push({ id, name, sourceUrl: href });
  }

  return degrees;
}

function parseEtsiiTable(table, semester, groupName, collected) {
  const rows = [...table.querySelectorAll('tr')];

  for (const row of rows) {
    const header = row.querySelector('th')?.textContent?.replace(/\s+/g, ' ').trim();
    if (!header || !TIME_SLOTS[header]) continue;

    const [startHour, endHour] = TIME_SLOTS[header];
    const cells = [...row.querySelectorAll('td')];

    for (let day = 0; day < Math.min(cells.length, DAYS.length); day++) {
      const activities = [...cells[day].querySelectorAll('div.asig > span')];

      for (const activity of activities) {
        const acronym = cleanSubject(activity.childNodes[0]?.textContent ?? '');
        if (!acronym) continue;

        const subjectKey = slugify(acronym);
        const key = `${subjectKey}:${groupName}:${semester}`;
        if (!collected.has(key)) {
          collected.set(key, {
            subjectId: subjectKey,
            acronym,
            group: {
              id: `${subjectKey}-${slugify(groupName)}-${semester.toLowerCase()}`,
              name: `${groupName} (${semester})`,
              type: 'theory',
              professorSet: new Set(),
              sessionSet: new Set(),
              sessions: [],
            },
          });
        }

        const entry = collected.get(key);
        for (const label of activity.querySelectorAll('label')) {
          for (const attr of label.getAttributeNames()) {
            if (attr.startsWith('data-balloon-')) {
              extractProfessors(label.getAttribute(attr) ?? '').forEach((professor) => entry.group.professorSet.add(professor));
            }
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

async function loadEtsiiSchedule(page, degreeValue, course, group) {
  try {
    await page.goto(ETSII_SCHEDULE_URL, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await page.selectOption('#tit', degreeValue);
    await page.selectOption('#curso', String(course));
    await page.selectOption('#gruposT', String(group), { timeout: 5000 });

    const [popup] = await Promise.all([
      page.waitForEvent('popup'),
      page.locator('form#f_horarios a.btn').click(),
    ]);

    await popup.waitForLoadState('networkidle');
    await popup.locator('input[name=contenido]').waitFor({ state: 'attached', timeout: 15000 });
    const html = await popup.locator('input[name=contenido]').getAttribute('value');
    await popup.close();
    return html ?? '';
  } catch (error) {
    console.warn(`Sin horario legible para titulación ${degreeValue}, curso ${course}, grupo ${group}: ${error.message}`);
    return '';
  }
}

async function scrapeEtsiiDegree(page, degree) {
  const collected = new Map();
  const rawByGroup = {};

  for (const course of [1, 2, 3, 4]) {
    for (const group of [1, 2, 3]) {
      const groupName = `${course}T${group}`;
      const html = await loadEtsiiSchedule(page, degree.formValue, course, group);
      if (!html) continue;
      rawByGroup[groupName] = html;
      const dom = new JSDOM(html);
      const tables = [...dom.window.document.querySelectorAll('table:not(.referencia)')];
      tables.forEach((table, index) => parseEtsiiTable(table, index === 0 ? 'C1' : 'C2', groupName, collected));
    }
  }

  const subjectsById = new Map();
  for (const { subjectId, acronym, group } of collected.values()) {
    if (!subjectsById.has(subjectId)) {
      subjectsById.set(subjectId, {
        id: subjectId,
        name: acronym,
        code: acronym,
        credits: 6,
        course: Number(group.name[0]) || 1,
        semester: group.name.includes('(C1)') && group.name.includes('(C2)') ? 'A' : group.name.includes('(C2)') ? 'C2' : 'C1',
        type: 'obligatoria',
        groups: [],
      });
    }

    subjectsById.get(subjectId).groups.push({
      id: group.id,
      name: group.name,
      professor: [...group.professorSet].join(', ') || 'Profesorado por determinar',
      professors: [...group.professorSet],
      type: group.type,
      sessions: group.sessions.sort((a, b) => a.day - b.day || a.startHour - b.startHour),
    });
  }

  return {
    degree: { id: degree.id, name: degree.name, source: 'ETSII horarios' },
    subjects: [...subjectsById.values()].sort((a, b) => a.course - b.course || a.name.localeCompare(b.name, 'es')),
    rawByGroup,
  };
}

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage();

const catalogDegrees = await scrapeDegreeCatalog(page);
const subjectsByDegree = {};
const scrapedDegrees = [];

for (const degree of ETSII_DEGREES) {
  console.log(`Extrayendo horarios ETSII: ${degree.name}`);
  const result = await scrapeEtsiiDegree(page, degree);
  scrapedDegrees.push(result.degree);
  subjectsByDegree[degree.id] = result.subjects;
}

await browser.close();

const degreeById = new Map(catalogDegrees.map((degree) => [degree.id, degree]));
for (const degree of scrapedDegrees) {
  degreeById.set(degree.id, degree);
}

fs.writeFileSync(
  OUTPUT,
  JSON.stringify({
    generatedAt: new Date().toISOString(),
    catalogSource: DEGREE_CATALOG_URL,
    degrees: [...degreeById.values()].sort((a, b) => a.name.localeCompare(b.name, 'es')),
    subjectsByDegree,
    notes: [
      'El catálogo de grados se extrae de la oferta oficial de la Universidad de Sevilla.',
      'Los horarios se extraen mediante adaptadores por facultad/centro porque la US no publica un formato único para todos los centros.',
      'Este script incluye el adaptador ETSII; añade nuevos adaptadores para páginas HTML/PDF de otras facultades en este mismo flujo.',
    ],
  }, null, 2),
  'utf8',
);

console.log(`Extraídos ${degreeById.size} grados y horarios de ${Object.keys(subjectsByDegree).length} titulaciones en ${OUTPUT}`);
