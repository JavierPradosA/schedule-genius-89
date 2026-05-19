import { useEffect, useMemo, useState } from 'react';
import { Button } from '@/components/ui/button';
import { SUBJECTS, Subject } from '@/data/demoData';
import { ArrowLeft, ArrowRight, BookOpen, FlaskConical, GraduationCap } from 'lucide-react';
import { Badge } from '@/components/ui/badge';

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

  useEffect(() => {
    if (!degree) {
      setDegree('giti');
    }
  }, [degree, setDegree]);

  const activeDegree = degree || 'giti';
  const subjects = useMemo(() => SUBJECTS[activeDegree] || [], [activeDegree]);
  const courses = useMemo(() => [...new Set(subjects.map(s => s.course))].sort(), [subjects]);

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
        Grado en Ingeniería Informática – Tecnologías Informáticas (Universidad de Sevilla)
      </p>
      <p className="text-sm text-muted-foreground mb-8">
        Elige las asignaturas que quieres matricular. Filtra por curso, cuatrimestre o tipo.
      </p>

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
            const noGroups = subject.groups.length === 0;
            return (
              <button
                type="button"
                key={subject.id}
                onClick={() => !noGroups && toggleSubject(subject)}
                disabled={noGroups}
                aria-pressed={selected}
                aria-label={`${selected ? 'Quitar' : 'Seleccionar'} ${subject.name}`}
                className={`w-full flex items-center justify-between p-4 rounded-lg border-2 transition-all text-left ${
                  noGroups
                    ? 'border-border opacity-50 cursor-not-allowed'
                    : selected
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
