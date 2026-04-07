import { DAYS, TIME_BLOCKS, TimeBlock, getSubjectColor } from '@/data/demoData';
import { ScheduleSession } from '@/lib/scheduleGenerator';
import { Ban } from 'lucide-react';

interface WeekCalendarProps {
  sessions: ScheduleSession[];
  blockedTimes?: TimeBlock[];
  compact?: boolean;
}

const WeekCalendar = ({ sessions, blockedTimes = [], compact = false }: WeekCalendarProps) => {
  const blockHeight = compact ? 36 : 56;
  const headerHeight = 40;

  const allHours = sessions.map(s => [s.startHour, s.endHour]).flat();
  const blockedHours = blockedTimes.map(b => [b.startHour, b.endHour]).flat();
  const combinedHours = [...allHours, ...blockedHours];
  const minHour = combinedHours.length > 0 ? Math.min(...combinedHours) : 8;
  const maxHour = combinedHours.length > 0 ? Math.max(...combinedHours) : 14;

  const visibleBlocks = TIME_BLOCKS.filter(b => b.start >= minHour - 2 && b.end <= maxHour + 2);

  const isBlocked = (day: number, startHour: number, endHour: number) =>
    blockedTimes.some(b => b.day === day && startHour < b.endHour && b.startHour < endHour);

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
              {/* Block grid lines + blocked zones */}
              {visibleBlocks.map(block => {
                const blocked = isBlocked(dayIdx, block.start, block.end);
                return (
                  <div
                    key={block.start}
                    className={`border-b border-border/30 ${blocked ? 'bg-destructive/8' : ''}`}
                    style={{ height: blockHeight }}
                  >
                    {blocked && !sessions.some(s => s.day === dayIdx && s.startHour === block.start) && (
                      <div className="flex items-center justify-center h-full">
                        <Ban className="w-3 h-3 text-destructive/30" />
                      </div>
                    )}
                  </div>
                );
              })}

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
                  const onBlockedTime = isBlocked(dayIdx, session.startHour, session.endHour);

                  return (
                    <div
                      key={`${session.subjectId}-${i}`}
                      className={`absolute inset-x-0.5 rounded-md px-1.5 py-1 text-xs overflow-hidden transition-transform hover:scale-[1.02] hover:z-10 ${onBlockedTime ? 'ring-2 ring-destructive ring-offset-1' : ''}`}
                      style={{
                        top,
                        height,
                        backgroundColor: color,
                        color: 'white',
                        opacity: onBlockedTime ? 0.7 : 0.92,
                      }}
                    >
                      <div className="font-semibold truncate text-[10px] leading-tight">
                        {onBlockedTime && '⚠ '}{session.subjectName}
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
