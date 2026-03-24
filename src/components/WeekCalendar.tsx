import { DAYS, HOURS, getSubjectColor } from '@/data/demoData';
import { ScheduleSession } from '@/lib/scheduleGenerator';

interface WeekCalendarProps {
  sessions: ScheduleSession[];
  compact?: boolean;
}

const WeekCalendar = ({ sessions, compact = false }: WeekCalendarProps) => {
  const hourHeight = compact ? 36 : 48;
  const headerHeight = 40;

  return (
    <div className="overflow-x-auto rounded-lg border border-border">
      <div className="min-w-[600px]">
        {/* Header */}
        <div className="grid grid-cols-6 border-b border-border bg-muted/50">
          <div className="p-2 text-center text-xs font-medium text-muted-foreground" style={{ height: headerHeight }}>
            Hora
          </div>
          {DAYS.map(day => (
            <div key={day} className="p-2 text-center text-xs font-semibold text-foreground" style={{ height: headerHeight }}>
              {day}
            </div>
          ))}
        </div>

        {/* Grid */}
        <div className="relative grid grid-cols-6">
          {/* Time column */}
          <div className="border-r border-border">
            {HOURS.map(hour => (
              <div
                key={hour}
                className="flex items-start justify-center border-b border-border/50 px-1 pt-1 text-xs text-muted-foreground"
                style={{ height: hourHeight }}
              >
                {hour}:00
              </div>
            ))}
          </div>

          {/* Day columns */}
          {[0, 1, 2, 3, 4].map(dayIdx => (
            <div key={dayIdx} className="relative border-r border-border last:border-r-0">
              {/* Hour grid lines */}
              {HOURS.map(hour => (
                <div key={hour} className="border-b border-border/30" style={{ height: hourHeight }} />
              ))}

              {/* Sessions */}
              {sessions
                .filter(s => s.day === dayIdx)
                .map((session, i) => {
                  const top = (session.startHour - 8) * hourHeight;
                  const height = (session.endHour - session.startHour) * hourHeight;
                  const color = getSubjectColor(session.colorIndex);

                  return (
                    <div
                      key={`${session.subjectId}-${i}`}
                      className="absolute inset-x-0.5 rounded-md px-1.5 py-1 text-xs overflow-hidden transition-transform hover:scale-[1.02] hover:z-10"
                      style={{
                        top,
                        height,
                        backgroundColor: color,
                        color: 'white',
                        opacity: 0.92,
                      }}
                    >
                      <div className="font-semibold truncate text-[10px] leading-tight">
                        {session.subjectName}
                      </div>
                      {!compact && height > hourHeight && (
                        <>
                          <div className="truncate text-[9px] opacity-80">{session.groupName}</div>
                          <div className="truncate text-[9px] opacity-70">{session.professor}</div>
                        </>
                      )}
                    </div>
                  );
                })}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

export default WeekCalendar;
