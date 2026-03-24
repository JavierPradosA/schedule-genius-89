import { Button } from '@/components/ui/button';
import { DAYS, HOURS, TimeBlock } from '@/data/demoData';
import { ArrowLeft, ArrowRight, Ban } from 'lucide-react';

interface StepPreferencesProps {
  blockedTimes: TimeBlock[];
  setBlockedTimes: (b: TimeBlock[]) => void;
  onNext: () => void;
  onBack: () => void;
}

const StepPreferences = ({ blockedTimes, setBlockedTimes, onNext, onBack }: StepPreferencesProps) => {
  const isBlocked = (day: number, hour: number) =>
    blockedTimes.some(b => b.day === day && b.startHour === hour);

  const toggleBlock = (day: number, hour: number) => {
    if (isBlocked(day, hour)) {
      setBlockedTimes(blockedTimes.filter(b => !(b.day === day && b.startHour === hour)));
    } else {
      setBlockedTimes([...blockedTimes, { day: day as TimeBlock['day'], startHour: hour, endHour: hour + 1 }]);
    }
  };

  const blockAfternoons = () => {
    const newBlocks: TimeBlock[] = [];
    for (let d = 0; d < 5; d++) {
      for (let h = 15; h < 20; h++) {
        if (!isBlocked(d, h)) {
          newBlocks.push({ day: d as TimeBlock['day'], startHour: h, endHour: h + 1 });
        }
      }
    }
    setBlockedTimes([...blockedTimes, ...newBlocks]);
  };

  const clearAll = () => setBlockedTimes([]);

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

          {/* Time slots */}
          {HOURS.map(hour => (
            <div key={hour} className="grid grid-cols-6 border-b border-border/50 last:border-b-0">
              <div className="p-2 text-center text-xs text-muted-foreground flex items-center justify-center">
                {hour}:00
              </div>
              {[0, 1, 2, 3, 4].map(day => {
                const blocked = isBlocked(day, hour);
                return (
                  <button
                    key={day}
                    onClick={() => toggleBlock(day, hour)}
                    className={`h-10 border-l border-border/30 transition-colors ${
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
