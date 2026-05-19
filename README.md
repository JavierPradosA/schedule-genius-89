# OptimaUS

OptimaUS es una aplicación React para planificar horarios universitarios a partir de asignaturas, turnos, restricciones horarias y preferencias de profesor.

## Scripts

```bash
npm install
npm run dev
npm run build
npm run lint
npm test
```

## Flujo principal

1. Selección de asignaturas por curso, cuatrimestre y tipo.
2. Marcado de franjas no disponibles.
3. Generación de horarios optimizados por solapamientos, restricciones, profesores preferidos y huecos.
4. Revisión visual del calendario y descarga de resumen.

## Datos

Los datos estáticos de asignaturas, grupos, horarios y profesorado viven en `src/data/demoData.ts`. Se han cargado para el Grado en Ingeniería Informática - Tecnologías Informáticas, curso 2025-26, a partir del plan de estudios de la Universidad de Sevilla y del horario oficial de la ETSII.

La app no consulta la web de la ETSII en tiempo de ejecución. La lógica de puntuación y generación está en `src/lib/scheduleGenerator.ts`.

## Valoraciones anónimas

La encuesta final se guarda en Supabase sin datos personales. El navegador genera un `idSesion` aleatorio por sesión y solo se envían estas respuestas:

- `facilidad_uso`
- `utilidad_percibida`
- `recomendacion`

Configuración:

1. Ejecuta el SQL de `supabase/feedback_final.sql` en el editor SQL de Supabase.
2. Crea un archivo `.env.local` a partir de `.env.example`.
3. Añade `VITE_SUPABASE_URL` y `VITE_SUPABASE_ANON_KEY`.
4. Reinicia `npm run dev`.

Si prefieres crear la tabla desde terminal, define temporalmente `SUPABASE_DB_PASSWORD` y ejecuta:

```bash
npm run setup:supabase
```

No guardes la URL de conexión directa de Postgres en archivos del proyecto.
