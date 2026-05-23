import { useEffect, useMemo, useState } from 'react';
import { Button } from '@/components/ui/button';
import { Subject } from '@/data/demoData';
import { Input } from '@/components/ui/input';
import { AlertCircle, ArrowLeft, ArrowRight, BookOpen, Database, FlaskConical, GraduationCap, Loader2, Search } from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { Degree, FALLBACK_ETSII_DEGREES, fetchEtsiiDegrees, fetchSubjectsForDegree } from '@/lib/academicData';

interface StepSelectionProps {
  degree: string;
  setDegree: (d: string) => void;
  selectedSubjects: Subject[];
  setSelectedSubjects: (s: Subject[]) => void;
  onNext: () => void;
  onBack: () => void;
}

const SEMESTER_OPTIONS = [
  { value: null, label: 'Todos' },
  { value: 'C1', label: '1er Cuatrimestre' },
  { value: 'C2', label: '2do Cuatrimestre' },
  { value: 'A', label: 'Anual' },
];

const TYPE_OPTIONS = [
  { value: null, label: 'Todas' },
  { value: 'obligatoria', label: 'Obligatorias' },
  { value: 'optativa', label: 'Optativas' },
];

const StepSelection = ({ degree, setDegree, selectedSubjects, setSelectedSubjects, onNext, onBack }: StepSelectionProps) => {
  const [course, setCourse] = useState<number | null>(null);
  const [semester, setSemester] = useState<string | null>(null);
  const [typeFilter, setTypeFilter] = useState<string | null>(null);
  const [degreeSearch, setDegreeSearch] = useState('');
  const [degrees, setDegrees] = useState<Degree[]>(FALLBACK_ETSII_DEGREES);
  const [subjects, setSubjects] = useState<Subject[]>([]);
  const [degreeSource, setDegreeSource] = useState<'supabase' | 'fallback'>('fallback');
  const [subjectSource, setSubjectSource] = useState<'supabase' | 'fallback'>('fallback');
  const [loadingDegrees, setLoadingDegrees] = useState(true);
  const [loadingSubjects, setLoadingSubjects] = useState(false);

  useEffect(() => {
    let ignore = false;

    async function loadDegrees() {
      setLoadingDegrees(true);
      const result = await fetchEtsiiDegrees();
      if (ignore) return;

      setDegrees(result.degrees);
      setDegreeSource(result.source);
      setLoadingDegrees(false);

      if (result.degrees.length > 0 && !degree) {
        setDegree(result.degrees[0].id);
      }
    }

    loadDegrees();

    return () => {
      ignore = true;
    };
  }, [degree, setDegree]);

  const activeDegree = degree || degrees[0]?.id || '';
  const activeDegreeInfo = degrees.find(d => d.id === activeDegree);

  useEffect(() => {
    if (!activeDegree) {
      setSubjects([]);
      return;
    }

    let ignore = false;

    async function loadSubjects() {
      setLoadingSubjects(true);
      const result = await fetchSubjectsForDegree(activeDegree);
      if (ignore) return;

      setSubjects(result.subjects);
      setSubjectSource(result.source);
      setLoadingSubjects(false);
    }

    loadSubjects();

    return () => {
      ignore = true;
    };
  }, [activeDegree]);

  const courses = useMemo(() => [...new Set(subjects.map(s => s.course))].sort(), [subjects]);
  const subjectsWithSchedules = subjects.filter((subject) =>
    subject.groups.some((group) => group.sessions.length > 0)
  ).length;
  const filteredDegrees = degrees.filter((d) =>
    d.name.toLocaleLowerCase('es').includes(degreeSearch.toLocaleLowerCase('es'))
  );

  const filteredSubjects = subjects.filter(s => {
    if (course && s.course !== course) return false;
    if (semester && s.semester !== semester) return false;
    if (typeFilter && s.type !== typeFilter) return false;
    return true;
  });

  const toggleSubject = (subject: Subject) => {
    if (selectedSubjects.find(s => s.id === subject.id)) {
      setSelectedSubjects(selectedSubjects.filter(s => s.id !== subject.id));
    } else {
      setSelectedSubjects([...selectedSubjects, subject]);
    }
  };

  const handleDegreeChange = (nextDegree: string) => {
    setDegree(nextDegree);
    setSelectedSubjects([]);
    setCourse(null);
    setSemester(null);
    setTypeFilter(null);
  };

  const totalCredits = selectedSubjects.reduce((sum, s) => sum + s.credits, 0);

  return (
    <div className="max-w-3xl mx-auto px-4 py-10">
      <div className="flex items-center gap-3 mb-2">
        <GraduationCap className="w-7 h-7 text-secondary" />
        <h2 className="font-display text-2xl sm:text-3xl font-bold text-foreground">
          Selecciona tus asignaturas
        </h2>
      </div>
      <p className="text-muted-foreground mb-2">
        {activeDegreeInfo?.name ?? 'Universidad de Sevilla'}
      </p>
      <p className="text-sm text-muted-foreground mb-8">
        Elige las asignaturas que quieres matricular. Filtra por curso, cuatrimestre o tipo.
      </p>

      <div className="mb-5 flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
        <span className="inline-flex items-center gap-1 rounded-md border border-border bg-muted/50 px-2 py-1">
          {loadingDegrees || loadingSubjects ? (
            <Loader2 className="h-3.5 w-3.5 animate-spin" />
          ) : (
            <Database className="h-3.5 w-3.5" />
          )}
          {degreeSource === 'supabase' || subjectSource === 'supabase'
            ? 'Datos desde Supabase'
            : 'Usando copia local hasta cargar Supabase'}
        </span>
        <span className="inline-flex items-center gap-1 rounded-md border border-border bg-muted/50 px-2 py-1">
          {degrees.length} grados ETSII
        </span>
      </div>

      <div className="mb-6">
        <label className="text-sm font-semibold text-foreground mb-2 block">Grado</label>
        <div className="relative mb-3">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            value={degreeSearch}
            onChange={(event) => setDegreeSearch(event.target.value)}
            placeholder="Buscar grado de la ETSII"
            className="pl-9"
          />
        </div>
        <div className="max-h-48 overflow-y-auto rounded-lg border border-border">
          {filteredDegrees.map((d) => (
            <button
              type="button"
              key={d.id}
              onClick={() => handleDegreeChange(d.id)}
              aria-pressed={activeDegree === d.id}
              className={`w-full px-4 py-3 text-left text-sm transition-colors ${
                activeDegree === d.id
                  ? 'bg-primary text-primary-foreground'
                  : 'hover:bg-muted/70'
              }`}
            >
              {d.name}
            </button>
          ))}
          {filteredDegrees.length === 0 && (
            <p className="px-4 py-6 text-center text-sm text-muted-foreground">No hay grados con esa búsqueda.</p>
          )}
        </div>
      </div>

      {subjectSource === 'fallback' && degreeSource === 'supabase' && (
        <div className="mb-6 flex gap-2 rounded-lg border border-amber-500/30 bg-amber-500/10 p-3 text-sm text-foreground">
          <AlertCircle className="mt-0.5 h-4 w-4 shrink-0 text-amber-700" />
          <span>
            Este grado existe en Supabase, pero no tiene asignaturas relacionadas en <code>degree_subjects</code>. Muestro la copia local para que puedas seguir probando.
          </span>
        </div>
      )}

      {loadingSubjects && (
        <div className="mb-6 flex items-center gap-2 rounded-lg border border-border bg-muted/40 p-3 text-sm text-muted-foreground">
          <Loader2 className="h-4 w-4 animate-spin" />
          Cargando asignaturas y grupos desde la base de datos...
        </div>
      )}

      {!loadingSubjects && subjects.length > 0 && subjectsWithSchedules === 0 && (
        <div className="mb-6 rounded-lg border border-amber-500/30 bg-amber-500/10 p-3 text-sm text-foreground">
          Este grado tiene cargado el plan oficial de asignaturas, pero todavía no hay una fuente pública estructurada de horarios y profesorado por grupo para generar horarios automáticos.
        </div>
      )}

      {!loadingSubjects && subjectsWithSchedules > 0 && subjectsWithSchedules < subjects.length && (
        <div className="mb-6 rounded-lg border border-secondary/30 bg-secondary/10 p-3 text-sm text-foreground">
          Hay {subjectsWithSchedules} asignatura{subjectsWithSchedules > 1 ? 's' : ''} con horarios/profesorado detectados. El resto aparece como plan oficial pendiente de horario público estructurado.
        </div>
      )}

      {/* Course filter */}
      <div className="mb-4">
        <label className="text-sm font-semibold text-foreground mb-2 block">Curso</label>
        <div className="flex flex-wrap gap-2">
          <button
            type="button"
            onClick={() => setCourse(null)}
            aria-pressed={course === null}
            className={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${
              course === null ? 'bg-primary text-primary-foreground' : 'bg-muted text-muted-foreground hover:bg-muted/80'
            }`}
          >
            Todos
          </button>
          {courses.map(c => (
            <button
              type="button"
              key={c}
              onClick={() => setCourse(c)}
              aria-pressed={course === c}
              className={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${
                course === c ? 'bg-primary text-primary-foreground' : 'bg-muted text-muted-foreground hover:bg-muted/80'
              }`}
            >
              {c}º Curso
            </button>
          ))}
        </div>
      </div>

      {/* Semester filter */}
      <div className="mb-4">
        <label className="text-sm font-semibold text-foreground mb-2 block">Cuatrimestre</label>
        <div className="flex flex-wrap gap-2">
          {SEMESTER_OPTIONS.map(opt => (
            <button
              type="button"
              key={opt.label}
              onClick={() => setSemester(opt.value)}
              aria-pressed={semester === opt.value}
              className={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${
                semester === opt.value ? 'bg-primary text-primary-foreground' : 'bg-muted text-muted-foreground hover:bg-muted/80'
              }`}
            >
              {opt.label}
            </button>
          ))}
        </div>
      </div>

      {/* Type filter */}
      <div className="mb-6">
        <label className="text-sm font-semibold text-foreground mb-2 block">Tipo</label>
        <div className="flex flex-wrap gap-2">
          {TYPE_OPTIONS.map(opt => (
            <button
              type="button"
              key={opt.label}
              onClick={() => setTypeFilter(opt.value)}
              aria-pressed={typeFilter === opt.value}
              className={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${
                typeFilter === opt.value ? 'bg-primary text-primary-foreground' : 'bg-muted text-muted-foreground hover:bg-muted/80'
              }`}
            >
              {opt.label}
            </button>
          ))}
        </div>
      </div>

      {/* Summary */}
      {selectedSubjects.length > 0 && (
        <div className="mb-4 p-3 rounded-lg bg-secondary/10 border border-secondary/30 flex items-center justify-between">
          <span className="text-sm font-medium text-foreground">
            {selectedSubjects.length} asignatura{selectedSubjects.length > 1 ? 's' : ''} seleccionada{selectedSubjects.length > 1 ? 's' : ''}
          </span>
          <Badge className="bg-secondary text-secondary-foreground">{totalCredits} ECTS</Badge>
        </div>
      )}

      {/* Subjects */}
      <div className="mb-8">
        <div className="space-y-2">
          {filteredSubjects.map(subject => {
            const selected = !!selectedSubjects.find(s => s.id === subject.id);
            const hasLab = subject.groups.some(g => g.type === 'lab');
            const noSchedule = !subject.groups.some((group) => group.sessions.length > 0);
            return (
              <button
                type="button"
                key={subject.id}
                onClick={() => toggleSubject(subject)}
                aria-pressed={selected}
                aria-label={`${selected ? 'Quitar' : 'Seleccionar'} ${subject.name}`}
                className={`w-full flex items-center justify-between p-4 rounded-lg border-2 transition-all text-left ${
                  selected
                      ? 'border-secondary bg-secondary/10 shadow-card'
                      : 'border-border hover:border-secondary/40'
                }`}
              >
                <div className="flex items-center gap-3">
                  <div className={`w-5 h-5 rounded-md border-2 flex items-center justify-center ${
                    selected ? 'bg-secondary border-secondary' : 'border-border'
                  }`}>
                    {selected && <span className="text-secondary-foreground text-xs">✓</span>}
                  </div>
                  <div>
                    <span className="font-medium text-foreground">{subject.name}</span>
                    <span className="text-xs text-muted-foreground ml-2">{subject.code}</span>
                    <div className="flex items-center gap-2 mt-0.5">
                      <span className="text-xs text-muted-foreground">{subject.course}º curso</span>
                      <span className="text-xs text-muted-foreground">·</span>
                      <span className="text-xs text-muted-foreground">
                        {subject.semester === 'A' ? 'Anual' : subject.semester === 'C1' ? 'C1' : 'C2'}
                      </span>
                      {subject.type === 'optativa' && (
                        <>
                          <span className="text-xs text-muted-foreground">·</span>
                          <span className="text-xs text-accent font-medium">Optativa</span>
                        </>
                      )}
                    </div>
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  {hasLab && (
                    <span className="flex items-center gap-1 text-xs text-muted-foreground bg-muted px-2 py-0.5 rounded-full">
                      <FlaskConical className="w-3 h-3" />Lab
                    </span>
                  )}
                  {noSchedule && (
                    <span className="flex items-center gap-1 text-xs text-amber-700 bg-amber-500/10 px-2 py-0.5 rounded-full">
                      Sin horario
                    </span>
                  )}
                  <span className="flex items-center gap-1 text-xs text-muted-foreground">
                    <BookOpen className="w-3 h-3" />{subject.credits} ECTS
                  </span>
                </div>
              </button>
            );
          })}
          {filteredSubjects.length === 0 && (
            <p className="text-center text-muted-foreground py-8">No hay asignaturas con esos filtros.</p>
          )}
        </div>
      </div>

      {/* Navigation */}
      <div className="flex justify-between">
        <Button variant="outline" onClick={onBack}>
          <ArrowLeft className="w-4 h-4 mr-1" /> Volver
        </Button>
        <Button
          onClick={onNext}
          disabled={selectedSubjects.length === 0}
          className="gradient-gold text-primary font-semibold"
        >
          Siguiente <ArrowRight className="w-4 h-4 ml-1" />
        </Button>
      </div>
    </div>
  );
};

export default StepSelection;
