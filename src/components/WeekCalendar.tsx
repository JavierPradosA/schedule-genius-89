import { DAYS, TIME_BLOCKS, TimeBlock, getSubjectColor } from '@/data/demoData';
import { ScheduleSession } from '@/lib/scheduleGenerator';
import { Ban, AlertTriangle } from 'lucide-react';
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from '@/components/ui/tooltip';

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

              {/* Sessions with overlap detection */}
              {(() => {
                const daySessions = sessions.filter(s => s.day === dayIdx);
                
                // Find overlapping groups
                const overlapGroups: ScheduleSession[][] = [];
                const assigned = new Set<number>();
                
                for (let i = 0; i < daySessions.length; i++) {
                  if (assigned.has(i)) continue;
                  const group = [daySessions[i]];
                  assigned.add(i);
                  for (let j = i + 1; j < daySessions.length; j++) {
                    if (assigned.has(j)) continue;
                    // Check if j overlaps with any in the group
                    const overlaps = group.some(
                      g => g.startHour < daySessions[j].endHour && daySessions[j].startHour < g.endHour
                    );
                    if (overlaps) {
                      group.push(daySessions[j]);
                      assigned.add(j);
                    }
                  }
                  overlapGroups.push(group);
                }

                return overlapGroups.flatMap(group => {
                  const isOverlap = group.length > 1;
                  return group.map((session, posInGroup) => {
                    const blockIdx = visibleBlocks.findIndex(b => b.start === session.startHour);
                    if (blockIdx === -1) return null;
                    const spanBlocks = visibleBlocks.filter(b => b.start >= session.startHour && b.end <= session.endHour).length || 1;
                    const top = blockIdx * blockHeight;
                    const height = spanBlocks * blockHeight;
                    const color = getSubjectColor(session.colorIndex);
                    const onBlockedTime = isBlocked(dayIdx, session.startHour, session.endHour);

                    // Side-by-side layout for overlaps
                    const width = isOverlap ? `calc(${100 / group.length}% - 2px)` : 'calc(100% - 4px)';
                    const left = isOverlap ? `calc(${(posInGroup * 100) / group.length}% + 1px)` : '2px';

                    return (
                      <TooltipProvider key={`${session.subjectId}-${session.startHour}-${posInGroup}`}>
                        <Tooltip>
                          <TooltipTrigger asChild>
                            <div
                              className={`absolute rounded-md px-1 py-0.5 text-xs overflow-hidden transition-transform hover:scale-[1.03] hover:z-20 cursor-default
                                ${isOverlap ? 'ring-2 ring-destructive/70 ring-offset-1 z-10' : ''}
                                ${onBlockedTime ? 'ring-2 ring-destructive ring-offset-1' : ''}`}
                              style={{
                                top,
                                height,
                                width,
                                left,
                                backgroundColor: color,
                                color: 'white',
                                opacity: onBlockedTime ? 0.7 : 0.95,
                              }}
                            >
                              {isOverlap && (
                                <div className="absolute -top-1.5 -right-1.5 bg-destructive rounded-full p-0.5 z-20">
                                  <AlertTriangle className="w-2.5 h-2.5 text-destructive-foreground" />
                                </div>
                              )}
                              <div className="font-semibold truncate text-[10px] leading-tight">
                                {onBlockedTime && '⚠ '}{session.subjectName}
                              </div>
                              {!compact && (
                                <div className="truncate text-[9px] opacity-80">{session.groupName}</div>
                              )}
                            </div>
                          </TooltipTrigger>
                          <TooltipContent side="top" className={isOverlap ? 'border-destructive bg-destructive/10' : ''}>
                            <p className="font-semibold">{session.subjectName}</p>
                            <p className="text-xs">{session.groupName} — {session.professor}</p>
                            {isOverlap && (
                              <p className="text-xs text-destructive font-medium mt-1">
                                ⚠ Solapamiento con: {group.filter(g => g !== session).map(g => g.subjectName).join(', ')}
                              </p>
                            )}
                          </TooltipContent>
                        </Tooltip>
                      </TooltipProvider>
                    );
                  });
                });
              })()}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

export default WeekCalendar;
