import { Button } from '@/components/ui/button';
import { DAYS, TIME_BLOCKS, TimeBlock, Subject } from '@/data/demoData';
import { SEMESTER_LABELS, SemesterKey } from '@/lib/semesterSchedules';
import { ArrowLeft, ArrowRight, Ban, User } from 'lucide-react';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';

export type ProfessorPreferences = Record<string, string | undefined>; // subjectId -> preferred professor name

interface StepPreferencesProps {
  blockedTimes: TimeBlock[];
  setBlockedTimes: (b: TimeBlock[]) => void;
  selectedSubjects: Subject[];
  professorPrefs: ProfessorPreferences;
  setProfessorPrefs: (p: ProfessorPreferences) => void;
  onNext: () => void;
  onBack: () => void;
}

const StepPreferences = ({ blockedTimes, setBlockedTimes, selectedSubjects, professorPrefs, setProfessorPrefs, onNext, onBack }: StepPreferencesProps) => {
  const isBlocked = (day: number, startHour: number) =>
    blockedTimes.some(b => b.day === day && b.startHour === startHour);

  const toggleBlock = (day: number, block: typeof TIME_BLOCKS[number]) => {
    if (isBlocked(day, block.start)) {
      setBlockedTimes(blockedTimes.filter(b => !(b.day === day && b.startHour === block.start)));
    } else {
      setBlockedTimes([...blockedTimes, { day: day as TimeBlock['day'], startHour: block.start, endHour: block.end }]);
    }
  };

  const blockAfternoons = () => {
    const afternoonBlocks = TIME_BLOCKS.filter(b => b.start >= 15);
    const newBlocks: TimeBlock[] = [];
    for (let d = 0; d < 5; d++) {
      for (const block of afternoonBlocks) {
        if (!isBlocked(d, block.start)) {
          newBlocks.push({ day: d as TimeBlock['day'], startHour: block.start, endHour: block.end });
        }
      }
    }
    setBlockedTimes([...blockedTimes, ...newBlocks]);
  };

  const blockMornings = () => {
    const morningBlocks = TIME_BLOCKS.filter(b => b.start < 15);
    const newBlocks: TimeBlock[] = [];
    for (let d = 0; d < 5; d++) {
      for (const block of morningBlocks) {
        if (!isBlocked(d, block.start)) {
          newBlocks.push({ day: d as TimeBlock['day'], startHour: block.start, endHour: block.end });
        }
      }
    }
    setBlockedTimes([...blockedTimes, ...newBlocks]);
  };

  const clearAll = () => setBlockedTimes([]);

  const subjectsBySemester = (['C1', 'C2'] as SemesterKey[]).map((semester) => ({
    semester,
    label: SEMESTER_LABELS[semester],
    subjects: selectedSubjects
      .filter((subject) => subject.semester === semester || subject.semester === 'A')
      .map(sub => {
      const professors = [...new Set(
        sub.groups.flatMap(g => g.professors?.length ? g.professors : [g.professor])
      )].sort((a, b) => a.localeCompare(b, 'es'));
      return { id: sub.id, name: sub.name, professors };
      }),
  })).filter((group) => group.subjects.length > 0);

  return (
    <div className="max-w-4xl mx-auto px-4 py-10">
      <h2 className="font-display text-2xl sm:text-3xl font-bold text-foreground mb-2">
        Tus preferencias horarias
      </h2>
      <p className="text-muted-foreground mb-4">
        Haz clic en las franjas que <strong>no estás disponible</strong> (trabajo, transporte, etc.)
      </p>

      {/* Quick actions */}
      <div className="flex flex-wrap gap-2 mb-6">
        <Button variant="outline" size="sm" onClick={blockAfternoons}>
          <Ban className="w-3 h-3 mr-1" /> Bloquear tardes
        </Button>
        <Button variant="outline" size="sm" onClick={blockMornings}>
          <Ban className="w-3 h-3 mr-1" /> Bloquear mañanas
        </Button>
        <Button variant="outline" size="sm" onClick={clearAll}>
          Limpiar todo
        </Button>
      </div>

      {/* Grid */}
      <div className="overflow-x-auto rounded-lg border border-border mb-8">
        <div className="min-w-[550px]">
          {/* Header */}
          <div className="grid grid-cols-6 bg-muted/50 border-b border-border">
            <div className="p-2 text-center text-xs font-medium text-muted-foreground">Hora</div>
            {DAYS.map(day => (
              <div key={day} className="p-2 text-center text-xs font-semibold text-foreground">{day}</div>
            ))}
          </div>

          {/* Time blocks */}
          {TIME_BLOCKS.map(block => (
            <div key={block.start} className="grid grid-cols-6 border-b border-border/50 last:border-b-0">
              <div className="p-2 text-center text-[11px] text-muted-foreground flex items-center justify-center">
                {block.label}
              </div>
              {[0, 1, 2, 3, 4].map(day => {
                const blocked = isBlocked(day, block.start);
                return (
                  <button
                    type="button"
                    key={day}
                    onClick={() => toggleBlock(day, block)}
                    aria-pressed={blocked}
                    aria-label={`${blocked ? 'Desbloquear' : 'Bloquear'} ${DAYS[day]}, ${block.label}`}
                    className={`h-12 border-l border-border/30 transition-colors ${
                      blocked
                        ? 'bg-destructive/20 hover:bg-destructive/30'
                        : 'hover:bg-muted/60'
                    }`}
                  >
                    {blocked && <Ban className="w-3.5 h-3.5 mx-auto text-destructive" />}
                  </button>
                );
              })}
            </div>
          ))}
        </div>
      </div>

      {/* Legend */}
      <div className="flex items-center gap-4 mb-8 text-xs text-muted-foreground">
        <div className="flex items-center gap-1.5">
          <div className="w-4 h-4 rounded bg-destructive/20 border border-destructive/30" />
          No disponible
        </div>
        <div className="flex items-center gap-1.5">
          <div className="w-4 h-4 rounded bg-background border border-border" />
          Disponible
        </div>
      </div>

      {/* Professor preferences - always visible */}
      <div className="mb-8">
        <h3 className="flex items-center gap-2 text-base font-semibold text-foreground mb-4">
          <User className="w-4 h-4" />
          Preferencia de profesores
          <span className="text-xs text-muted-foreground font-normal">(opcional — prioriza el grupo de ese profesor)</span>
        </h3>

        {subjectsBySemester.length > 0 ? (
          <div className="space-y-6 pl-4 border-l-2 border-primary/30">
            {subjectsBySemester.map((semesterGroup) => (
              <div key={semesterGroup.semester}>
                <h4 className="mb-3 text-sm font-semibold text-foreground">{semesterGroup.label}</h4>
                <div className="space-y-3">
                  {semesterGroup.subjects.map(sub => (
                    <div key={`${semesterGroup.semester}-${sub.id}`} className="flex flex-col sm:flex-row sm:items-center gap-1.5 sm:gap-3">
                      <span className="text-sm text-foreground/80 min-w-[220px]">{sub.name}</span>
                      {sub.professors.length > 1 ? (
                        <Select
                          value={professorPrefs[sub.id] || '_any'}
                          onValueChange={val =>
                            setProfessorPrefs({ ...professorPrefs, [sub.id]: val === '_any' ? undefined : val })
                          }
                        >
                          <SelectTrigger className="h-8 text-xs w-full sm:w-[260px]">
                            <SelectValue placeholder="Sin preferencia" />
                          </SelectTrigger>
                          <SelectContent>
                            <SelectItem value="_any">Sin preferencia</SelectItem>
                            {sub.professors.map(prof => (
                              <SelectItem key={prof} value={prof}>{prof}</SelectItem>
                            ))}
                          </SelectContent>
                        </Select>
                      ) : (
                        <span className="text-xs text-muted-foreground">Sin alternativas de profesor</span>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            ))}
          </div>
        ) : (
          <p className="text-sm text-muted-foreground italic">
            Selecciona asignaturas para ver sus profesores por cuatrimestre.
          </p>
        )}
      </div>

      {/* Navigation */}
      <div className="flex justify-between">
        <Button variant="outline" onClick={onBack}>
          <ArrowLeft className="w-4 h-4 mr-1" /> Volver
        </Button>
        <Button onClick={onNext} className="gradient-gold text-primary font-semibold">
          Generar horarios <ArrowRight className="w-4 h-4 ml-1" />
        </Button>
      </div>
    </div>
  );
};

export default StepPreferences;
