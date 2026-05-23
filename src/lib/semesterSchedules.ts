import { Subject } from '@/data/demoData';
import { ScheduleOption, generateSchedules } from '@/lib/scheduleGenerator';
import { ProfessorPreferences } from '@/components/steps/StepPreferences';
import { TimeBlock } from '@/data/demoData';

export type SemesterKey = 'C1' | 'C2';

export interface SemesterScheduleResult {
  semester: SemesterKey;
  label: string;
  options: ScheduleOption[];
  warnings: ReturnType<typeof generateSchedules>['warnings'];
}

export interface ChosenSemesterSchedule {
  semester: SemesterKey;
  label: string;
  schedule: ScheduleOption;
}

export const SEMESTER_LABELS: Record<SemesterKey, string> = {
  C1: '1er cuatrimestre',
  C2: '2º cuatrimestre',
};

const SEMESTER_SUFFIX: Record<SemesterKey, string> = {
  C1: '(C1)',
  C2: '(C2)',
};

export function getSubjectsForSemester(subjects: Subject[], semester: SemesterKey): Subject[] {
  return subjects.flatMap((subject) => {
    if (subject.semester !== 'A' && subject.semester !== semester) {
      return [];
    }

    if (subject.semester !== 'A') {
      return [subject];
    }

    const hasTaggedGroups = subject.groups.some((group) => /\(C[12]\)/.test(group.name));
    const groups = hasTaggedGroups
      ? subject.groups.filter((group) => group.name.includes(SEMESTER_SUFFIX[semester]))
      : subject.groups;

    return [{
      ...subject,
      semester,
      groups,
    }];
  });
}

export function generateSemesterSchedules(
  subjects: Subject[],
  blockedTimes: TimeBlock[],
  professorPrefs?: ProfessorPreferences,
): SemesterScheduleResult[] {
  const semesters = (['C1', 'C2'] as SemesterKey[]).filter((semester) =>
    subjects.some((subject) => subject.semester === semester || subject.semester === 'A')
  );

  return semesters.map((semester) => ({
    semester,
    label: SEMESTER_LABELS[semester],
    ...generateSchedules(getSubjectsForSemester(subjects, semester), blockedTimes, professorPrefs),
  }));
}
