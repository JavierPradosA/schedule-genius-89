import { useEffect, useMemo, useState } from 'react';
import { Button } from '@/components/ui/button';
import { Subject, TimeBlock } from '@/data/demoData';
import { ScheduleOption } from '@/lib/scheduleGenerator';
import { ChosenSemesterSchedule, generateSemesterSchedules, SemesterKey } from '@/lib/semesterSchedules';
import { ProfessorPreferences } from '@/components/steps/StepPreferences';
import WeekCalendar from '@/components/WeekCalendar';
import { ArrowLeft, Check, AlertTriangle, Info } from 'lucide-react';
import { motion } from 'framer-motion';

interface StepResultsProps {
  subjects: Subject[];
  blockedTimes: TimeBlock[];
  professorPrefs?: ProfessorPreferences;
  onChoose: (schedules: ChosenSemesterSchedule[]) => void;
  onBack: () => void;
}

const StepResults = ({ subjects, blockedTimes, professorPrefs, onChoose, onBack }: StepResultsProps) => {
  const semesterResults = useMemo(() => {
    return generateSemesterSchedules(subjects, blockedTimes, professorPrefs);
  }, [subjects, blockedTimes, professorPrefs]);

  const [activeSemester, setActiveSemester] = useState<SemesterKey>('C1');
  const [selectedIdxBySemester, setSelectedIdxBySemester] = useState<Record<SemesterKey, number>>({ C1: 0, C2: 0 });

  useEffect(() => {
    if (semesterResults.length > 0 && !semesterResults.some((result) => result.semester === activeSemester)) {
      setActiveSemester(semesterResults[0].semester);
    }
  }, [activeSemester, semesterResults]);

  const activeResult = semesterResults.find((result) => result.semester === activeSemester) ?? semesterResults[0];
  const currentIndex = activeResult
    ? Math.min(selectedIdxBySemester[activeResult.semester] ?? 0, Math.max(activeResult.options.length - 1, 0))
    : 0;
  const current = activeResult?.options[currentIndex];
  const hasMultipleSemesters = semesterResults.length > 1;
  const chosenSchedules = semesterResults.flatMap((result) => {
    const optionIndex = Math.min(
      selectedIdxBySemester[result.semester] ?? 0,
      Math.max(result.options.length - 1, 0),
    );
    const schedule = result.options[optionIndex];
    return schedule ? [{ semester: result.semester, label: result.label, schedule }] : [];
  });

  if (!activeResult || activeResult.options.length === 0) {
    return (
      <div className="max-w-3xl mx-auto px-4 py-16 text-center">
        <AlertTriangle className="w-12 h-12 text-destructive mx-auto mb-4" />
        <h2 className="font-display text-2xl font-bold text-foreground mb-2">
          No se encontraron combinaciones válidas para el {activeResult?.label ?? 'cuatrimestre seleccionado'}
        </h2>
        <p className="text-muted-foreground mb-4">
          Prueba a modificar tus restricciones horarias o revisar las asignaturas de ese cuatrimestre.
        </p>
        {hasMultipleSemesters && (
          <div className="flex flex-wrap justify-center gap-3 mb-6">
            {semesterResults.map((result) => (
              <button
                type="button"
                key={result.semester}
                onClick={() => setActiveSemester(result.semester)}
                aria-pressed={activeSemester === result.semester}
                className={`px-4 py-2 rounded-lg border text-sm font-medium transition-all ${
                  activeSemester === result.semester
                    ? 'border-secondary bg-secondary/10 text-foreground'
                    : 'border-border text-muted-foreground hover:border-secondary/40'
                }`}
              >
                {result.label}
              </button>
            ))}
          </div>
        )}
        {activeResult?.warnings.length > 0 && (
          <div className="text-left max-w-md mx-auto mb-6 space-y-2">
            {activeResult.warnings.map((w, i) => (
              <div key={i} className="flex items-start gap-2 bg-destructive/10 border border-destructive/30 rounded-lg p-3">
                <AlertTriangle className="w-4 h-4 text-destructive mt-0.5 flex-shrink-0" />
                <p className="text-sm text-foreground">{w.message}</p>
              </div>
            ))}
          </div>
        )}
        <Button variant="outline" onClick={onBack}>
          <ArrowLeft className="w-4 h-4 mr-1" /> Modificar preferencias
        </Button>
      </div>
    );
  }

  return (
    <div className="max-w-5xl mx-auto px-4 py-10">
      <h2 className="font-display text-2xl sm:text-3xl font-bold text-foreground mb-2">
        Tus horarios sugeridos
      </h2>
      <p className="text-muted-foreground mb-6">
        Hemos generado {activeResult.options.length} opción(es) optimizadas para tu {activeResult.label}.
      </p>

      {hasMultipleSemesters && (
        <div className="mb-6 space-y-3">
          <div className="flex items-start gap-2 bg-secondary/10 border border-secondary/30 rounded-lg p-3">
            <Info className="w-4 h-4 text-secondary mt-0.5 flex-shrink-0" />
            <p className="text-sm text-foreground">
              Hemos separado las asignaturas por cuatrimestre para no mezclar materias de C1 y C2 en un mismo horario.
            </p>
          </div>

          <div className="flex flex-wrap gap-3">
            {semesterResults.map((result) => (
              <button
                type="button"
                key={result.semester}
                onClick={() => setActiveSemester(result.semester)}
                aria-pressed={activeSemester === result.semester}
                className={`px-4 py-3 rounded-lg border-2 text-left transition-all ${
                  activeSemester === result.semester
                    ? 'border-secondary bg-secondary/10 shadow-card'
                    : 'border-border hover:border-secondary/40'
                }`}
              >
                <div className="font-semibold text-sm text-foreground">{result.label}</div>
                <div className="text-xs text-muted-foreground mt-0.5">
                  {result.options.length} opción(es) · {result.warnings.length} aviso(s)
                </div>
              </button>
            ))}
          </div>
        </div>
      )}

      {/* Warnings */}
      {activeResult.warnings.length > 0 && (
        <div className="space-y-2 mb-6">
          {activeResult.warnings.map((w, i) => (
            <div key={i} className="flex items-start gap-2 bg-amber-500/10 border border-amber-500/30 rounded-lg p-3">
              <AlertTriangle className="w-4 h-4 text-amber-600 mt-0.5 flex-shrink-0" />
              <p className="text-sm text-foreground">{w.message}</p>
            </div>
          ))}
        </div>
      )}

      {/* Option tabs */}
      <div className="flex flex-wrap gap-3 mb-6">
        {activeResult.options.map((opt, i) => (
          <button
            type="button"
            key={opt.id}
            onClick={() => setSelectedIdxBySemester((prev) => ({ ...prev, [activeResult.semester]: i }))}
            aria-pressed={currentIndex === i}
            className={`px-4 py-3 rounded-lg border-2 text-left transition-all ${
              currentIndex === i
                ? 'border-secondary bg-secondary/10 shadow-card'
                : 'border-border hover:border-secondary/40'
            }`}
          >
            <div className="font-semibold text-sm text-foreground">{opt.label}</div>
            <div className="text-xs text-muted-foreground mt-0.5">{opt.description}</div>
          </button>
        ))}
      </div>

      {/* Why this option */}
      {current.conflicts === 0 && (
        <motion.div
          key={current.id}
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          className="flex items-start gap-2 bg-secondary/10 border border-secondary/30 rounded-lg p-3 mb-4"
        >
          <Info className="w-4 h-4 text-secondary mt-0.5 flex-shrink-0" />
          <p className="text-sm text-foreground">
            <strong>¿Por qué esta opción?</strong>{' '}
            {current.id === 'compact' && 'Minimiza los huecos muertos entre clases, concentrando tu jornada.'}
            {current.id === 'mornings' && 'Todas las clases son por la mañana, dejando las tardes completamente libres.'}
            {current.id === 'minimal-gaps' && 'Prioriza la menor cantidad de tiempo perdido entre clases.'}
            {current.id === 'alternative' && 'Una alternativa válida con diferente distribución de turnos.'}
            {current.id === 'selection-only' && 'Puedes continuar con tu selección de asignaturas aunque todavía no haya horario/profesorado público cargado para este grado.'}
          </p>
        </motion.div>
      )}

      {current.blockedViolations > 0 && (
        <div className="flex items-start gap-2 bg-amber-500/10 border border-amber-500/30 rounded-lg p-3 mb-4">
          <AlertTriangle className="w-4 h-4 text-amber-600 mt-0.5 flex-shrink-0" />
          <p className="text-sm text-foreground">
            Este horario tiene <strong>{current.blockedViolations} clase(s) en franjas que bloqueaste</strong> porque no existe ningún turno que las evite. Se marcan con borde rojo en el calendario.
          </p>
        </div>
      )}

      {current.conflicts > 0 && (
        <div className="flex items-start gap-2 bg-destructive/10 border border-destructive/30 rounded-lg p-3 mb-4">
          <AlertTriangle className="w-4 h-4 text-destructive mt-0.5 flex-shrink-0" />
          <p className="text-sm text-foreground">
            Este horario tiene <strong>{current.conflicts} solapamiento(s)</strong> entre asignaturas. Considera modificar tu selección.
          </p>
        </div>
      )}

      {/* Calendar */}
      <div className="mb-8">
        <WeekCalendar sessions={current.sessions} blockedTimes={blockedTimes} />
      </div>

      {/* Navigation */}
      <div className="flex justify-between">
        <Button variant="outline" onClick={onBack}>
          <ArrowLeft className="w-4 h-4 mr-1" /> Modificar
        </Button>
        <Button onClick={() => onChoose(chosenSchedules)} className="gradient-gold text-primary font-semibold">
          <Check className="w-4 h-4 mr-1" /> Aceptar horarios
        </Button>
      </div>
    </div>
  );
};

export default StepResults;
