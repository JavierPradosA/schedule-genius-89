import fs from 'node:fs';
import path from 'node:path';

const ROOT = process.cwd();
const schemaPath = path.join(ROOT, 'supabase', 'academic_etsii.sql');
const seedPath = path.join(ROOT, 'supabase', 'seed_etsii_academic.sql');
const cleanupPath = path.join(ROOT, 'supabase', 'cleanup_combined_etsii_subjects.sql');
const outputPath = path.join(ROOT, 'supabase', 'academic_etsii_full.sql');

const parts = [
  '-- 1. Esquema academico ETSII',
  fs.readFileSync(schemaPath, 'utf8'),
  '-- 2. Seed corregido: solo asignaturas reales del plan, sin combinaciones de horario',
  fs.readFileSync(seedPath, 'utf8'),
  '-- 3. Limpieza defensiva por si habia datos antiguos',
  fs.readFileSync(cleanupPath, 'utf8'),
];

fs.writeFileSync(outputPath, `${parts.join('\n\n')}\n`, 'utf8');
console.log(`SQL completo generado: ${path.relative(ROOT, outputPath)}`);
