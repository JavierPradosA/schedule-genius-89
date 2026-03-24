import { Subject, SubjectGroup, TimeBlock, Session } from '@/data/demoData';

export interface ScheduleOption {
  id: string;
  label: string;
  description: string;
  score: number;
  conflicts: number;
  gaps: number;
  selections: { subjectId: string; groupId: string }[];
  sessions: ScheduleSession[];
}

export interface ScheduleSession {
  subjectId: string;
  subjectName: string;
  groupName: string;
  professor: string;
  type: 'theory' | 'lab';
  day: number;
  startHour: number;
  endHour: number;
  colorIndex: number;
}

function hasOverlap(a: Session, b: Session): boolean {
  if (a.day !== b.day) return false;
  return a.startHour < b.endHour && b.startHour < a.endHour;
}

function countGaps(sessions: ScheduleSession[]): number {
  let gaps = 0;
  for (let day = 0; day < 5; day++) {
    const daySessions = sessions.filter(s => s.day === day).sort((a, b) => a.startHour - b.startHour);
    for (let i = 1; i < daySessions.length; i++) {
      const gap = daySessions[i].startHour - daySessions[i - 1].endHour;
      if (gap > 0) gaps += gap;
    }
  }
  return gaps;
}

function isBlockedTime(session: Session, blocked: TimeBlock[]): boolean {
  return blocked.some(b => b.day === session.day && session.startHour < b.endHour && b.startHour < session.endHour);
}

function hasAfternoons(sessions: ScheduleSession[]): boolean {
  return sessions.some(s => s.startHour >= 15);
}

export function generateSchedules(
  subjects: Subject[],
  blockedTimes: TimeBlock[],
  _preferredProfessors: string[] = [],
  _preferLabMorning: boolean = false,
): ScheduleOption[] {
  // For each subject, pick valid groups (not blocked)
  const validGroupsPerSubject = subjects.map(subject => {
    return subject.groups.filter(group => {
      return !group.sessions.some(session => isBlockedTime(session, blockedTimes));
    });
  });

  // Generate combinations (limit to avoid explosion)
  const combinations: SubjectGroup[][] = [];
  
  function backtrack(idx: number, current: SubjectGroup[]) {
    if (combinations.length >= 50) return;
    if (idx === subjects.length) {
      combinations.push([...current]);
      return;
    }
    const groups = validGroupsPerSubject[idx];
    if (groups.length === 0) {
      // No valid groups, try all groups anyway
      for (const g of subjects[idx].groups) {
        current.push(g);
        backtrack(idx + 1, current);
        current.pop();
      }
    } else {
      for (const g of groups) {
        current.push(g);
        backtrack(idx + 1, current);
        current.pop();
      }
    }
  }
  
  backtrack(0, []);

  // Score each combination
  const scored = combinations.map((combo, i) => {
    const allSessions: Session[] = combo.flatMap(g => g.sessions);
    let conflicts = 0;
    for (let a = 0; a < allSessions.length; a++) {
      for (let b = a + 1; b < allSessions.length; b++) {
        if (hasOverlap(allSessions[a], allSessions[b])) conflicts++;
      }
    }

    const scheduleSessions: ScheduleSession[] = combo.flatMap((group, gi) => 
      group.sessions.map(s => ({
        subjectId: subjects[gi].id,
        subjectName: subjects[gi].name,
        groupName: group.name,
        professor: group.professor,
        type: group.type,
        day: s.day,
        startHour: s.startHour,
        endHour: s.endHour,
        colorIndex: gi,
      }))
    );

    const gaps = countGaps(scheduleSessions);
    const afternoons = hasAfternoons(scheduleSessions);

    // Score: lower is better. Conflicts heavily penalized.
    const score = conflicts * 100 + gaps * 5 + (afternoons ? 10 : 0);

    return {
      id: `option-${i}`,
      conflicts,
      gaps,
      score,
      afternoons,
      selections: combo.map((g, gi) => ({ subjectId: subjects[gi].id, groupId: g.id })),
      sessions: scheduleSessions,
      combo,
    };
  });

  // Sort by score, take top options
  scored.sort((a, b) => a.score - b.score);

  const results: ScheduleOption[] = [];

  // Best compact
  const best = scored.find(s => s.conflicts === 0) || scored[0];
  if (best) {
    results.push({
      ...best,
      id: 'compact',
      label: '⚡ Horario más compacto',
      description: best.conflicts === 0
        ? `Sin solapamientos · ${best.gaps}h de huecos semanales`
        : `⚠️ ${best.conflicts} solapamiento(s) · ${best.gaps}h de huecos`,
    });
  }

  // Best afternoon-free
  const noAfternoon = scored.find(s => !s.afternoons && s.conflicts === 0);
  if (noAfternoon && noAfternoon.id !== best?.id) {
    results.push({
      ...noAfternoon,
      id: 'mornings',
      label: '☀️ Tardes libres',
      description: `Solo clases por la mañana · ${noAfternoon.gaps}h de huecos`,
    });
  }

  // Fewest gaps
  const minGaps = scored.filter(s => s.conflicts === 0).sort((a, b) => a.gaps - b.gaps)[0];
  if (minGaps && minGaps.id !== best?.id && minGaps.id !== noAfternoon?.id) {
    results.push({
      ...minGaps,
      id: 'minimal-gaps',
      label: '🎯 Menos huecos muertos',
      description: `Solo ${minGaps.gaps}h de huecos en toda la semana`,
    });
  }

  // If we have less than 2, add another variant
  if (results.length < 2 && scored.length > 1) {
    const alt = scored[1];
    results.push({
      ...alt,
      id: 'alternative',
      label: '🔄 Opción alternativa',
      description: alt.conflicts === 0
        ? `Sin solapamientos · ${alt.gaps}h de huecos`
        : `${alt.conflicts} solapamiento(s) · ${alt.gaps}h de huecos`,
    });
  }

  return results;
}
