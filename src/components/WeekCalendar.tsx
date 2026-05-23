import { DAYS, TIME_BLOCKS, TimeBlock, getSubjectColor } from '@/data/demoData';
import { ScheduleSession } from '@/lib/scheduleGenerator';
import { AlertTriangle, Ban, CheckCircle2 } from 'lucide-react';
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

  const blockedSessionCount = sessions.filter(s => isBlocked(s.day, s.startHour, s.endHour)).length;
  const conflictSessionCount = sessions.filter((session, index) =>
    sessions.some((other, otherIndex) =>
      otherIndex !== index &&
      other.day === session.day &&
      session.startHour < other.endHour &&
      other.startHour < session.endHour
    )
  ).length;
  const hasWarnings = blockedSessionCount > 0 || conflictSessionCount > 0;

  return (
    <div className="rounded-lg border border-border bg-card shadow-card">
      <div className="flex flex-col gap-3 border-b border-border px-4 py-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h3 className="text-sm font-semibold text-foreground">Vista semanal</h3>
          <p className="text-xs text-muted-foreground">
            {hasWarnings
              ? 'Revisa las marcas rojas antes de aceptar el horario.'
              : 'Horario sin solapes ni clases dentro de franjas bloqueadas.'}
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-2 text-xs">
          <span className="inline-flex items-center gap-1 rounded-md border border-emerald-500/30 bg-emerald-500/10 px-2 py-1 font-medium text-emerald-700">
            <CheckCircle2 className="h-3.5 w-3.5" />
            {sessions.length} clases
          </span>
          <span className={`inline-flex items-center gap-1 rounded-md border px-2 py-1 font-medium ${
            blockedSessionCount > 0
              ? 'border-destructive/40 bg-destructive/10 text-destructive'
              : 'border-border bg-muted/60 text-muted-foreground'
          }`}>
            <Ban className="h-3.5 w-3.5" />
            {blockedSessionCount} bloqueadas
          </span>
          <span className={`inline-flex items-center gap-1 rounded-md border px-2 py-1 font-medium ${
            conflictSessionCount > 0
              ? 'border-destructive/40 bg-destructive/10 text-destructive'
              : 'border-border bg-muted/60 text-muted-foreground'
          }`}>
            <AlertTriangle className="h-3.5 w-3.5" />
            {conflictSessionCount} con solape
          </span>
        </div>
      </div>

      <div className="flex flex-wrap gap-3 border-b border-border/70 px-4 py-2 text-[11px] text-muted-foreground">
        <span className="inline-flex items-center gap-1.5">
          <span className="h-3 w-3 rounded-sm border border-border bg-background" />
          Disponible
        </span>
        <span className="inline-flex items-center gap-1.5">
          <span className="h-3 w-3 rounded-sm border border-destructive/40 bg-destructive/10" />
          Franja bloqueada
        </span>
        <span className="inline-flex items-center gap-1.5">
          <span className="h-3 w-3 rounded-sm border-2 border-destructive bg-primary" />
          Clase con incidencia
        </span>
      </div>

      <div className="overflow-x-auto">
        <div className="min-w-[720px]">
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
                    className={`border-b border-border/30 ${blocked ? 'bg-destructive/10 bg-[repeating-linear-gradient(135deg,hsl(var(--destructive)/0.08)_0,hsl(var(--destructive)/0.08)_6px,transparent_6px,transparent_12px)]' : ''}`}
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
                      <TooltipProvider key={`${session.subjectId}-${session.groupName}-${session.day}-${session.startHour}-${session.endHour}-${posInGroup}`}>
                        <Tooltip>
                          <TooltipTrigger asChild>
                            <div
                              className={`absolute rounded-md px-1 py-0.5 text-xs overflow-hidden transition-transform hover:scale-[1.03] hover:z-20 cursor-default
                                ${isOverlap || onBlockedTime ? 'border-2 border-solid border-destructive' : 'border border-white/20'}`}
                              style={{
                                top,
                                height,
                                width,
                                left,
                                backgroundColor: color,
                                color: 'white',
                                opacity: onBlockedTime ? 0.75 : 0.92,
                                boxShadow: onBlockedTime ? '0 0 0 1px hsl(var(--destructive) / 0.35)' : undefined,
                              }}
                            >
                              <div className="font-semibold truncate text-[10px] leading-tight">
                                {session.subjectName}
                              </div>
                              {!compact && (
                                <div className="truncate text-[9px] opacity-80">{session.groupName}</div>
                              )}
                              {(isOverlap || onBlockedTime) && !compact && (
                                <div className="mt-0.5 flex gap-1">
                                  {onBlockedTime && (
                                    <span className="rounded-sm bg-destructive px-1 text-[8px] font-bold uppercase leading-3 text-destructive-foreground">
                                      Bloqueada
                                    </span>
                                  )}
                                  {isOverlap && (
                                    <span className="rounded-sm bg-destructive px-1 text-[8px] font-bold uppercase leading-3 text-destructive-foreground">
                                      Solape
                                    </span>
                                  )}
                                </div>
                              )}
                            </div>
                          </TooltipTrigger>
                          <TooltipContent side="top">
                            <p className="font-semibold">{session.subjectName}</p>
                            <p className="text-xs text-muted-foreground">{session.groupName} — {session.professor}</p>
                            {isOverlap && (
                              <p className="text-xs text-destructive/80 mt-1">
                                Solapamiento con: {group.filter(g => g !== session).map(g => g.subjectName).join(', ')}
                              </p>
                            )}
                            {onBlockedTime && (
                              <p className="text-xs text-destructive/80 mt-1">
                                Coincide con una franja bloqueada.
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
    </div>
  );
};

export default WeekCalendar;
