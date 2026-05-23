import { DEGREES, SUBJECTS, Subject, SubjectGroup, Session } from '@/data/demoData';
import { createSupabaseClient, isSupabaseConfigured } from '@/lib/supabaseClient';

export interface Degree {
  id: string;
  name: string;
  abbreviation?: string | null;
}

const ETSII_DEGREE_IDS = [
  'us-etsii-c',
  'us-etsii-s',
  'giti',
  'us-etsii-ia',
  'us-etsii-sa',
] as const;

export const FALLBACK_ETSII_DEGREES: Degree[] = ETSII_DEGREE_IDS
  .map((id) => DEGREES.find((degree) => degree.id === id))
  .filter((degree): degree is Degree => Boolean(degree));

const COMBINED_SUBJECT_PATTERN = /\s\/\s/;

function isOfficialSubject(subject: Subject): boolean {
  return !COMBINED_SUBJECT_PATTERN.test(subject.name) && !COMBINED_SUBJECT_PATTERN.test(subject.code);
}

function fallbackSubjectsForDegree(degreeId: string): Subject[] {
  return (SUBJECTS[degreeId] ?? []).filter(isOfficialSubject);
}

function normalizeSemester(value: unknown): Subject['semester'] {
  if (value === 'A' || value === 'C2') return value;
  return 'C1';
}

function normalizeType(value: unknown): Subject['type'] {
  return value === 'optativa' ? 'optativa' : 'obligatoria';
}

function timeToBlockHour(value: unknown): number {
  const time = String(value ?? '');
  const [hours, minutes] = time.split(':').map((part) => Number(part));
  if (Number.isNaN(hours)) return 8;

  if (hours === 8) return 8;
  if (hours === 10) return 10;
  if (hours === 12) return 12;
  if (hours === 15) return 15;
  if (hours === 17) return 17;
  if (hours === 19) return 19;

  const decimal = hours + ((Number.isNaN(minutes) ? 0 : minutes) / 60);
  if (decimal < 10.5) return 10;
  if (decimal < 12.5) return 12;
  if (decimal < 15.5) return 15;
  if (decimal < 17.5) return 17;
  if (decimal < 19.5) return 19;
  return 21;
}

function meetingToSession(meeting: Record<string, unknown>): Session | null {
  const weekday = Number(meeting.weekday);
  if (!Number.isInteger(weekday) || weekday < 1 || weekday > 5) return null;

  return {
    day: (weekday - 1) as Session['day'],
    startHour: timeToBlockHour(meeting.start_time),
    endHour: timeToBlockHour(meeting.end_time),
  };
}

function splitProfessors(value: unknown): string[] {
  return String(value ?? '')
    .split(/[,;\n]+/)
    .map((professor) => professor.trim())
    .filter(Boolean);
}

function mapGroup(row: Record<string, unknown>): SubjectGroup {
  const professor = String(row.professor ?? 'Profesorado pendiente').trim() || 'Profesorado pendiente';
  const professors = splitProfessors(professor);
  const meetings = Array.isArray(row.group_meetings) ? row.group_meetings : [];
  const firstMeetingType = meetings.find((meeting): meeting is Record<string, unknown> =>
    Boolean(meeting) && typeof meeting === 'object'
  )?.meeting_type;

  return {
    id: String(row.id),
    name: String(row.group_name ?? 'Grupo'),
    professor,
    professors: professors.length > 0 ? professors : [professor],
    type: firstMeetingType === 'lab' || firstMeetingType === 'practice' ? 'lab' : 'theory',
    sessions: meetings
      .map((meeting) => meetingToSession(meeting as Record<string, unknown>))
      .filter((session): session is Session => Boolean(session)),
  };
}

function mapSubject(row: Record<string, unknown>): Subject | null {
  const subject = row.subjects;
  if (!subject || typeof subject !== 'object') return null;

  const subjectRecord = subject as Record<string, unknown>;
  const groups = Array.isArray(subjectRecord.subject_groups) ? subjectRecord.subject_groups : [];

  return {
    id: String(subjectRecord.id),
    name: String(subjectRecord.name ?? 'Asignatura'),
    code: String(subjectRecord.code ?? subjectRecord.id),
    credits: Number(subjectRecord.credits ?? 0),
    course: Number(row.course ?? 1),
    semester: normalizeSemester(row.semester),
    type: normalizeType(row.type),
    mention: typeof row.mention === 'string' ? row.mention : undefined,
    groups: groups.map((group) => mapGroup(group as Record<string, unknown>)),
  };
}

export async function fetchEtsiiDegrees(): Promise<{ degrees: Degree[]; source: 'supabase' | 'fallback' }> {
  if (!isSupabaseConfigured) {
    return { degrees: FALLBACK_ETSII_DEGREES, source: 'fallback' };
  }

  try {
    const supabase = await createSupabaseClient();
    if (!supabase) return { degrees: FALLBACK_ETSII_DEGREES, source: 'fallback' };

    const { data, error } = await supabase
      .from('degrees')
      .select('id, name, abbreviation')
      .eq('center', 'ETSII')
      .eq('is_double_degree', false)
      .order('sort_order', { ascending: true })
      .order('name', { ascending: true });

    if (error || !data || data.length === 0) {
      return { degrees: FALLBACK_ETSII_DEGREES, source: 'fallback' };
    }

    return { degrees: data as Degree[], source: 'supabase' };
  } catch {
    return { degrees: FALLBACK_ETSII_DEGREES, source: 'fallback' };
  }
}

export async function fetchSubjectsForDegree(
  degreeId: string,
): Promise<{ subjects: Subject[]; source: 'supabase' | 'fallback' }> {
  if (!isSupabaseConfigured) {
    return { subjects: fallbackSubjectsForDegree(degreeId), source: 'fallback' };
  }

  try {
    const supabase = await createSupabaseClient();
    if (!supabase) return { subjects: fallbackSubjectsForDegree(degreeId), source: 'fallback' };

    const { data, error } = await supabase
      .from('degree_subjects')
      .select(`
        course,
        semester,
        type,
        mention,
        subjects (
          id,
          code,
          name,
          credits,
          subject_groups (
            id,
            group_name,
            professor,
            group_meetings (
              weekday,
              start_time,
              end_time,
              meeting_type
            )
          )
        )
      `)
      .eq('degree_id', degreeId)
      .order('course', { ascending: true })
      .order('semester', { ascending: true });

    if (error || !data || data.length === 0) {
      return { subjects: fallbackSubjectsForDegree(degreeId), source: 'fallback' };
    }

    return {
      subjects: data
        .map((row) => mapSubject(row as Record<string, unknown>))
        .filter((subject): subject is Subject => Boolean(subject) && isOfficialSubject(subject)),
      source: 'supabase',
    };
  } catch {
    return { subjects: fallbackSubjectsForDegree(degreeId), source: 'fallback' };
  }
}
