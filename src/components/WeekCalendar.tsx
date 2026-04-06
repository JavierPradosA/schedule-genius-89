import { DAYS, TIME_BLOCKS, getSubjectColor } from '@/data/demoData';
import { ScheduleSession } from '@/lib/scheduleGenerator';

interface WeekCalendarProps {
  sessions: ScheduleSession[];
  compact?: boolean;
}

const WeekCalendar = ({ sessions, compact = false }: WeekCalendarProps) => {
  const blockHeight = compact ? 36 : 56;
  const headerHeight = 40;

  // Determine which time blocks are needed
  const allHours = sessions.map(s => [s.startHour, s.endHour]).flat();
  const minHour = allHours.length > 0 ? Math.min(...allHours) : 8;
  const maxHour = allHours.length > 0 ? Math.max(...allHours) : 14;

  const visibleBlocks = TIME_BLOCKS.filter(b => b.start >= minHour - 2 && b.end <= maxHour + 2);

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
            {visibleBlocks.map(block => (
              <div
                key={block.start}
                className="flex items-center justify-center border-b border-border/50 px-1 text-[10px] text-muted-foreground"
                style={{ height: blockHeight }}
              >
                {block.label}
              </div>
            ))}
          </div>

          {/* Day columns */}
          {[0, 1, 2, 3, 4].map(dayIdx => (
            <div key={dayIdx} className="relative border-r border-border last:border-r-0">
              {/* Block grid lines */}
              {visibleBlocks.map(block => (
                <div key={block.start} className="border-b border-border/30" style={{ height: blockHeight }} />
              ))}

              {/* Sessions */}
              {sessions
                .filter(s => s.day === dayIdx)
                .map((session, i) => {
                  const blockIdx = visibleBlocks.findIndex(b => b.start === session.startHour);
                  if (blockIdx === -1) return null;
                  const spanBlocks = visibleBlocks.filter(b => b.start >= session.startHour && b.end <= session.endHour).length || 1;
                  const top = blockIdx * blockHeight;
                  const height = spanBlocks * blockHeight;
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
                      {!compact && (
                        <div className="truncate text-[9px] opacity-80">{session.groupName}</div>
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
