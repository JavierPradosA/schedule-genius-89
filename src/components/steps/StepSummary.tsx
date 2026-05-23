import { useState } from 'react';
import { Button } from '@/components/ui/button';
import WeekCalendar from '@/components/WeekCalendar';
import { TimeBlock } from '@/data/demoData';
import { getAnonymousSessionId, saveFeedback } from '@/lib/feedback';
import { ChosenSemesterSchedule } from '@/lib/semesterSchedules';
import { AlertTriangle, Ban, CheckCircle2, Download, RotateCcw, Star } from 'lucide-react';

interface StepSummaryProps {
  schedules: ChosenSemesterSchedule[];
  blockedTimes?: TimeBlock[];
  onBack: () => void;
  onRestart: () => void;
}

const StepSummary = ({ schedules, blockedTimes = [], onBack, onRestart }: StepSummaryProps) => {
  const [ratings, setRatings] = useState<Record<string, number>>({});
  const [submitted, setSubmitted] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState('');
  const totalSessions = schedules.reduce((sum, item) => sum + item.schedule.sessions.length, 0);
  const totalBlockedViolations = schedules.reduce((sum, item) => sum + item.schedule.blockedViolations, 0);
  const totalConflicts = schedules.reduce((sum, item) => sum + item.schedule.conflicts, 0);

  const handleDownload = () => {
    // Create a text summary for download
    const lines = [
      'RESUMEN DE MATRÍCULA',
      '====================',
      '',
    ];

    const days = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'];
    for (const item of schedules) {
      lines.push(item.label.toUpperCase());
      lines.push('-'.repeat(item.label.length));
      lines.push(`Opción: ${item.schedule.label}`);
      lines.push(item.schedule.description);
      lines.push('');
      lines.push('DETALLE DE CLASES:');
      lines.push('');

      for (let d = 0; d < 5; d++) {
        const daySessions = item.schedule.sessions.filter(s => s.day === d).sort((a, b) => a.startHour - b.startHour);
        if (daySessions.length > 0) {
          lines.push(`${days[d]}:`);
          daySessions.forEach(s => {
            lines.push(`  ${s.startHour}:00 - ${s.endHour}:00 | ${s.subjectName} (${s.groupName}) - ${s.professor}`);
          });
          lines.push('');
        }
      }

      const pendingSubjects = item.schedule.subjects.filter((subject) => subject.groupName === 'Horario pendiente');
      if (pendingSubjects.length > 0) {
        lines.push('ASIGNATURAS SIN HORARIO CARGADO:');
        pendingSubjects.forEach((subject) => {
          lines.push(`  ${subject.subjectName}`);
        });
        lines.push('');
      }
    }

    const blob = new Blob([lines.join('\n')], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'mi-horario-universitario.txt';
    a.click();
    URL.revokeObjectURL(url);
  };

  const surveyQuestions = [
    { id: 'ease', label: '¿Fue fácil de usar?' },
    { id: 'useful', label: '¿Te resultó útil?' },
    { id: 'recommend', label: '¿Lo recomendarías?' },
  ];

  const handleSubmitFeedback = async () => {
    setSubmitError('');
    setIsSubmitting(true);

    try {
      await saveFeedback({
        idSesion: getAnonymousSessionId(),
        facilidadUso: ratings.ease,
        utilidadPercibida: ratings.useful,
        recomendacion: ratings.recommend,
      });
      setSubmitted(true);
    } catch (error) {
      setSubmitError(
        error instanceof Error
          ? error.message
          : 'No se pudo guardar la valoración. Inténtalo de nuevo.',
      );
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="max-w-4xl mx-auto px-4 py-10">
      <div className="text-center mb-8">
        <div className="w-16 h-16 rounded-full bg-secondary/20 flex items-center justify-center mx-auto mb-4">
          <span className="text-3xl">🎓</span>
        </div>
        <h2 className="font-display text-2xl sm:text-3xl font-bold text-foreground mb-2">
          ¡Tu horario está listo!
        </h2>
        <p className="text-muted-foreground">
          Hemos preparado el horario del 1er y 2º cuatrimestre por separado.
        </p>
      </div>

      <div className="mb-6 grid gap-3 sm:grid-cols-3">
        <div className="rounded-lg border border-emerald-500/30 bg-emerald-500/10 p-3">
          <div className="flex items-center gap-2 text-sm font-semibold text-emerald-700">
            <CheckCircle2 className="h-4 w-4" />
            Clases
          </div>
          <p className="mt-1 text-2xl font-bold text-foreground">{totalSessions}</p>
        </div>
        <div className={`rounded-lg border p-3 ${
          totalBlockedViolations > 0
            ? 'border-destructive/40 bg-destructive/10'
            : 'border-border bg-muted/40'
        }`}>
          <div className={`flex items-center gap-2 text-sm font-semibold ${
            totalBlockedViolations > 0 ? 'text-destructive' : 'text-muted-foreground'
          }`}>
            <Ban className="h-4 w-4" />
            En franjas bloqueadas
          </div>
          <p className="mt-1 text-2xl font-bold text-foreground">{totalBlockedViolations}</p>
        </div>
        <div className={`rounded-lg border p-3 ${
          totalConflicts > 0
            ? 'border-destructive/40 bg-destructive/10'
            : 'border-border bg-muted/40'
        }`}>
          <div className={`flex items-center gap-2 text-sm font-semibold ${
            totalConflicts > 0 ? 'text-destructive' : 'text-muted-foreground'
          }`}>
            <AlertTriangle className="h-4 w-4" />
            Solapamientos
          </div>
          <p className="mt-1 text-2xl font-bold text-foreground">{totalConflicts}</p>
        </div>
      </div>

      <div className="mb-8 space-y-8">
        {schedules.map((item) => (
          <section key={item.semester} className="space-y-3">
            <div>
              <h3 className="font-display text-xl font-semibold text-foreground">{item.label}</h3>
              <p className="text-sm text-muted-foreground">
                {item.schedule.label} — {item.schedule.description}
              </p>
            </div>
            <WeekCalendar sessions={item.schedule.sessions} blockedTimes={blockedTimes} />
          </section>
        ))}
      </div>

      {/* Subject summary */}
      <div className="bg-card rounded-xl border border-border p-5 mb-8 shadow-card">
        <h3 className="font-display text-lg font-semibold text-foreground mb-3">Resumen de asignaturas</h3>
        <div className="space-y-5">
          {schedules.map((item) => (
            <div key={item.semester}>
              <h4 className="text-sm font-semibold text-foreground mb-2">{item.label}</h4>
              <div className="space-y-2">
                {item.schedule.subjects
                  .filter((s, i, arr) => arr.findIndex(x => x.subjectId === s.subjectId) === i)
                  .map(s => (
                    <div key={`${item.semester}-${s.subjectId}`} className="flex flex-col gap-1 py-2 border-b border-border/50 last:border-b-0 sm:flex-row sm:items-center sm:justify-between">
                      <div>
                        <span className="font-medium text-foreground">{s.subjectName}</span>
                        <span className="text-xs text-muted-foreground ml-2">{s.groupName}</span>
                      </div>
                      <span className="text-sm text-muted-foreground">{s.professor}</span>
                    </div>
                  ))}
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Actions */}
      <div className="flex flex-wrap gap-3 justify-center mb-10">
        <Button onClick={handleDownload} className="gradient-gold text-primary font-semibold">
          <Download className="w-4 h-4 mr-1" /> Descargar resumen
        </Button>
        <Button variant="outline" onClick={onBack}>
          Volver a resultados
        </Button>
        <Button variant="outline" onClick={onRestart}>
          <RotateCcw className="w-4 h-4 mr-1" /> Empezar de nuevo
        </Button>
      </div>

      {/* Survey */}
      <div className="bg-card rounded-xl border border-border p-6 shadow-card">
        <h3 className="font-display text-lg font-semibold text-foreground mb-1">¿Qué te pareció?</h3>
        <p className="text-sm text-muted-foreground mb-5">Tu opinión nos ayuda a mejorar. Puntúa del 1 al 5.</p>

        {!submitted ? (
          <>
            <div className="space-y-4 mb-6">
              {surveyQuestions.map(q => (
                <div key={q.id}>
                  <p className="text-sm font-medium text-foreground mb-2">{q.label}</p>
                  <div className="flex gap-2">
                    {[1, 2, 3, 4, 5].map(n => (
                      <button
                        type="button"
                        key={n}
                        onClick={() => setRatings({ ...ratings, [q.id]: n })}
                        aria-label={`${q.label} ${n} de 5`}
                        aria-pressed={(ratings[q.id] || 0) >= n}
                        className={`w-10 h-10 rounded-lg border-2 flex items-center justify-center transition-all ${
                          (ratings[q.id] || 0) >= n
                            ? 'border-secondary bg-secondary/20 text-secondary'
                            : 'border-border text-muted-foreground hover:border-secondary/50'
                        }`}
                      >
                        <Star className={`w-4 h-4 ${(ratings[q.id] || 0) >= n ? 'fill-current' : ''}`} />
                      </button>
                    ))}
                  </div>
                </div>
              ))}
            </div>
            <Button
              onClick={handleSubmitFeedback}
              disabled={Object.keys(ratings).length < surveyQuestions.length || isSubmitting}
              className="bg-primary text-primary-foreground"
            >
              {isSubmitting ? 'Enviando...' : 'Enviar valoración'}
            </Button>
            {submitError && (
              <p className="mt-3 text-sm text-destructive">
                No se ha podido guardar la valoración: {submitError}
              </p>
            )}
          </>
        ) : (
          <div className="text-center py-4">
            <p className="text-lg font-semibold text-foreground">¡Gracias por tu opinión! 🙌</p>
            <p className="text-sm text-muted-foreground mt-1">Tu feedback nos ayuda a mejorar.</p>
          </div>
        )}
      </div>
    </div>
  );
};

export default StepSummary;
