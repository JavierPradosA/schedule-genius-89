import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { ScheduleOption } from '@/lib/scheduleGenerator';
import WeekCalendar from '@/components/WeekCalendar';
import { Download, RotateCcw, Star } from 'lucide-react';

interface StepSummaryProps {
  schedule: ScheduleOption;
  onBack: () => void;
  onRestart: () => void;
}

const StepSummary = ({ schedule, onBack, onRestart }: StepSummaryProps) => {
  const [ratings, setRatings] = useState<Record<string, number>>({});
  const [submitted, setSubmitted] = useState(false);

  const handleDownload = () => {
    // Create a text summary for download
    const lines = [
      'RESUMEN DE MATRÍCULA',
      '====================',
      '',
      `Opción: ${schedule.label}`,
      `${schedule.description}`,
      '',
      'DETALLE DE CLASES:',
      '',
    ];

    const days = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'];
    for (let d = 0; d < 5; d++) {
      const daySessions = schedule.sessions.filter(s => s.day === d).sort((a, b) => a.startHour - b.startHour);
      if (daySessions.length > 0) {
        lines.push(`📅 ${days[d]}:`);
        daySessions.forEach(s => {
          lines.push(`  ${s.startHour}:00 - ${s.endHour}:00 | ${s.subjectName} (${s.groupName}) - ${s.professor}`);
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
          {schedule.label} — {schedule.description}
        </p>
      </div>

      {/* Calendar */}
      <div className="mb-8">
        <WeekCalendar sessions={schedule.sessions} />
      </div>

      {/* Subject summary */}
      <div className="bg-card rounded-xl border border-border p-5 mb-8 shadow-card">
        <h3 className="font-display text-lg font-semibold text-foreground mb-3">Resumen de asignaturas</h3>
        <div className="space-y-2">
          {schedule.sessions
            .filter((s, i, arr) => arr.findIndex(x => x.subjectId === s.subjectId) === i)
            .map(s => (
              <div key={s.subjectId} className="flex items-center justify-between py-2 border-b border-border/50 last:border-b-0">
                <div>
                  <span className="font-medium text-foreground">{s.subjectName}</span>
                  <span className="text-xs text-muted-foreground ml-2">{s.groupName}</span>
                </div>
                <span className="text-sm text-muted-foreground">{s.professor}</span>
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
                        key={n}
                        onClick={() => setRatings({ ...ratings, [q.id]: n })}
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
              onClick={() => setSubmitted(true)}
              disabled={Object.keys(ratings).length < surveyQuestions.length}
              className="bg-primary text-primary-foreground"
            >
              Enviar valoración
            </Button>
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
