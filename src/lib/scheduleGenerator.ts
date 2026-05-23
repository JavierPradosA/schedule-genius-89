import { Subject, SubjectGroup, TimeBlock, Session } from '@/data/demoData';

export interface ScheduleOption {
  id: string;
  label: string;
  description: string;
  score: number;
  conflicts: number;
  blockedViolations: number;
  gaps: number;
  selections: { subjectId: string; groupId: string }[];
  sessions: ScheduleSession[];
  subjects: ScheduleSubjectSummary[];
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

export interface ScheduleSubjectSummary {
  subjectId: string;
  subjectName: string;
  groupName: string;
  professor: string;
}

export interface ScheduleWarning {
  type: 'no_groups' | 'all_blocked' | 'unavoidable_conflict' | 'generation_limited';
  subjectId: string;
  subjectName: string;
  message: string;
}

const MAX_COMBINATIONS = 10000;

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

/** Check for warnings before generating schedules */
export function checkWarnings(subjects: Subject[], blockedTimes: TimeBlock[]): ScheduleWarning[] {
  const warnings: ScheduleWarning[] = [];

  for (const subject of subjects) {
    if (subject.groups.length === 0) {
      warnings.push({
        type: 'no_groups',
        subjectId: subject.id,
        subjectName: subject.name,
        message: `"${subject.name}" no tiene grupos/turnos disponibles y no se puede incluir en el horario.`,
      });
      continue;
    }

    const validGroups = subject.groups.filter(g =>
      !g.sessions.some(session => isBlockedTime(session, blockedTimes))
    );

    if (validGroups.length === 0) {
      warnings.push({
        type: 'all_blocked',
        subjectId: subject.id,
        subjectName: subject.name,
        message: `Todos los turnos de "${subject.name}" chocan con tus restricciones horarias. Se intentará incluir igualmente, pero habrá conflictos.`,
      });
    }
  }

  return warnings;
}

export function generateSchedules(
  subjects: Subject[],
  blockedTimes: TimeBlock[],
  professorPrefs?: Record<string, string | undefined>,
): { options: ScheduleOption[]; warnings: ScheduleWarning[] } {
  const warnings = checkWarnings(subjects, blockedTimes);

  const validSubjects = subjects.filter(s => s.groups.length > 0);
  const unscheduledSubjects = subjects.filter(s => s.groups.length === 0);

  if (validSubjects.length === 0) {
    if (subjects.length === 0) {
      return { options: [], warnings };
    }

    return {
      options: [{
        id: 'selection-only',
        label: 'Selección de asignaturas',
        description: 'Asignaturas cargadas desde el plan oficial, sin horario público estructurado.',
        score: 0,
        conflicts: 0,
        blockedViolations: 0,
        gaps: 0,
        selections: subjects.map((subject) => ({ subjectId: subject.id, groupId: 'pending-schedule' })),
        sessions: [],
        subjects: subjects.map((subject) => ({
          subjectId: subject.id,
          subjectName: subject.name,
          groupName: 'Horario pendiente',
          professor: 'Profesorado pendiente',
        })),
      }],
      warnings,
    };
  }

  // For each subject, get valid groups (not blocked), fallback to all
  const groupsPerSubject = validSubjects.map(subject => {
    const valid = subject.groups.filter(g =>
      !g.sessions.some(session => isBlockedTime(session, blockedTimes))
    );
    const candidates = valid.length > 0 ? valid : subject.groups;

    return [...candidates].sort((a, b) => {
      const pref = professorPrefs?.[subject.id];
      const scoreGroup = (group: SubjectGroup) => {
        const blockedPenalty = group.sessions.filter(session => isBlockedTime(session, blockedTimes)).length * 100;
        const groupProfessors = group.professors?.length ? group.professors : [group.professor];
        const preferencePenalty = pref && !groupProfessors.includes(pref) ? 10 : 0;
        const afternoonPenalty = group.sessions.some(session => session.startHour >= 15) ? 1 : 0;
        return blockedPenalty + preferencePenalty + afternoonPenalty;
      };

      return scoreGroup(a) - scoreGroup(b);
    });
  });

  // Generate combinations via backtracking. The cap prevents runaway work for very large selections.
  const combinations: SubjectGroup[][] = [];
  const estimatedCombinations = groupsPerSubject.reduce((total, groups) => total * groups.length, 1);
  let reachedLimit = false;

  function backtrack(idx: number, current: SubjectGroup[]) {
    if (combinations.length >= MAX_COMBINATIONS) {
      reachedLimit = true;
      return;
    }
    if (idx === validSubjects.length) {
      combinations.push([...current]);
      return;
    }
    for (const g of groupsPerSubject[idx]) {
      current.push(g);
      backtrack(idx + 1, current);
      current.pop();
    }
  }

  backtrack(0, []);

  if (reachedLimit || estimatedCombinations > MAX_COMBINATIONS) {
    warnings.push({
      type: 'generation_limited',
      subjectId: 'schedule-generation',
      subjectName: 'Generación de horarios',
      message: `La selección tiene ${estimatedCombinations.toLocaleString('es-ES')} combinaciones posibles. Se han evaluado las ${MAX_COMBINATIONS.toLocaleString('es-ES')} candidatas más prometedoras según restricciones y preferencias.`,
    });
  }

  if (combinations.length === 0) {
    return { options: [], warnings };
  }

  // Score each combination
  const scored = combinations.map((combo, i) => {
    const allSessions: Session[] = combo.flatMap(g => g.sessions);

    // Count overlaps between different subjects
    let conflicts = 0;
    for (let a = 0; a < combo.length; a++) {
      for (let b = a + 1; b < combo.length; b++) {
        for (const sa of combo[a].sessions) {
          for (const sb of combo[b].sessions) {
            if (hasOverlap(sa, sb)) conflicts++;
          }
        }
      }
    }

    // Count blocked time violations
    let blockedViolations = 0;
    for (const session of allSessions) {
      if (isBlockedTime(session, blockedTimes)) blockedViolations++;
    }

    const scheduleSessions: ScheduleSession[] = combo.flatMap((group, gi) =>
      group.sessions.map(sess => ({
        subjectId: validSubjects[gi].id,
        subjectName: validSubjects[gi].name,
        groupName: group.name,
        professor: group.professor,
        type: group.type,
        day: sess.day,
        startHour: sess.startHour,
        endHour: sess.endHour,
        colorIndex: gi,
      }))
    );
    const subjectSummaries: ScheduleSubjectSummary[] = [
      ...combo.map((group, gi) => ({
        subjectId: validSubjects[gi].id,
        subjectName: validSubjects[gi].name,
        groupName: group.name,
        professor: group.professor,
      })),
      ...unscheduledSubjects.map((subject) => ({
        subjectId: subject.id,
        subjectName: subject.name,
        groupName: 'Horario pendiente',
        professor: 'Profesorado pendiente',
      })),
    ];

    const gaps = countGaps(scheduleSessions);
    const afternoons = hasAfternoons(scheduleSessions);

    // Count professor preference mismatches
    let profMismatches = 0;
    if (professorPrefs) {
      for (let gi = 0; gi < combo.length; gi++) {
        const pref = professorPrefs[validSubjects[gi].id];
        const groupProfessors = combo[gi].professors?.length ? combo[gi].professors : [combo[gi].professor];
        if (pref && !groupProfessors.includes(pref)) {
          profMismatches++;
        }
      }
    }

    const score = conflicts * 200 + blockedViolations * 150 + profMismatches * 50 + gaps * 5 + (afternoons ? 10 : 0);

    return {
      id: `option-${i}`,
      conflicts,
      blockedViolations,
      gaps,
      score,
      afternoons,
      selections: combo.map((g, gi) => ({ subjectId: validSubjects[gi].id, groupId: g.id })),
      sessions: scheduleSessions,
      subjects: subjectSummaries,
    };
  });

  scored.sort((a, b) => a.score - b.score);

  const results: ScheduleOption[] = [];

  // Best compact
  const best = scored.find(s => s.conflicts === 0 && s.blockedViolations === 0) || scored.find(s => s.conflicts === 0) || scored[0];
  if (best) {
    const parts: string[] = [];
    if (best.conflicts > 0) parts.push(`⚠️ ${best.conflicts} solapamiento(s)`);
    if (best.blockedViolations > 0) parts.push(`🚫 ${best.blockedViolations} clase(s) en horario bloqueado`);
    if (best.conflicts === 0 && best.blockedViolations === 0) parts.push('Sin conflictos');
    parts.push(`${best.gaps}h de huecos`);

    results.push({
      ...best,
      id: 'compact',
      label: '⚡ Horario más compacto',
      description: parts.join(' · '),
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

  // Alternative
  if (results.length < 2 && scored.length > 1) {
    const alt = scored.find(s => s.id !== best?.id) || scored[1];
    results.push({
      ...alt,
      id: 'alternative',
      label: '🔄 Opción alternativa',
      description: alt.conflicts === 0
        ? `Sin solapamientos · ${alt.gaps}h de huecos`
        : `${alt.conflicts} solapamiento(s) · ${alt.gaps}h de huecos`,
    });
  }

  // Detect unavoidable conflicts between subject pairs
  if (!scored.some(s => s.conflicts === 0)) {
    // Find which subject pairs always conflict
    for (let a = 0; a < validSubjects.length; a++) {
      for (let b = a + 1; b < validSubjects.length; b++) {
        let alwaysConflict = true;
        for (const ga of groupsPerSubject[a]) {
          for (const gb of groupsPerSubject[b]) {
            let pairConflict = false;
            for (const sa of ga.sessions) {
              for (const sb of gb.sessions) {
                if (hasOverlap(sa, sb)) { pairConflict = true; break; }
              }
              if (pairConflict) break;
            }
            if (!pairConflict) { alwaysConflict = false; break; }
          }
          if (!alwaysConflict) break;
        }
        if (alwaysConflict) {
          warnings.push({
            type: 'unavoidable_conflict',
            subjectId: validSubjects[a].id,
            subjectName: `${validSubjects[a].name} + ${validSubjects[b].name}`,
            message: `"${validSubjects[a].name}" y "${validSubjects[b].name}" tienen solapamiento en TODOS los turnos disponibles. Considera cursar una de ellas en otro cuatrimestre.`,
          });
        }
      }
    }
  }

  return { options: results, warnings };
}
