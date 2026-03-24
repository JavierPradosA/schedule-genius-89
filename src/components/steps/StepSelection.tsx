import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { DEGREES, SUBJECTS, Subject } from '@/data/demoData';
import { ArrowLeft, ArrowRight, BookOpen, FlaskConical } from 'lucide-react';
import { Badge } from '@/components/ui/badge';

interface StepSelectionProps {
  degree: string;
  setDegree: (d: string) => void;
  selectedSubjects: Subject[];
  setSelectedSubjects: (s: Subject[]) => void;
  onNext: () => void;
  onBack: () => void;
}

const StepSelection = ({ degree, setDegree, selectedSubjects, setSelectedSubjects, onNext, onBack }: StepSelectionProps) => {
  const [course, setCourse] = useState<number | null>(null);
  const subjects = degree ? (SUBJECTS[degree] || []) : [];
  const filteredSubjects = course ? subjects.filter(s => s.course === course) : subjects;
  const courses = [...new Set(subjects.map(s => s.course))].sort();

  const toggleSubject = (subject: Subject) => {
    if (selectedSubjects.find(s => s.id === subject.id)) {
      setSelectedSubjects(selectedSubjects.filter(s => s.id !== subject.id));
    } else {
      setSelectedSubjects([...selectedSubjects, subject]);
    }
  };

  return (
    <div className="max-w-3xl mx-auto px-4 py-10">
      <h2 className="font-display text-2xl sm:text-3xl font-bold text-foreground mb-2">
        Selecciona tu titulación y asignaturas
      </h2>
      <p className="text-muted-foreground mb-8">
        Elige las asignaturas que necesitas matricular este cuatrimestre.
      </p>

      {/* Degree selection */}
      <div className="mb-6">
        <label className="text-sm font-semibold text-foreground mb-2 block">Titulación</label>
        <div className="grid sm:grid-cols-3 gap-3">
          {DEGREES.map(d => (
            <button
              key={d.id}
              onClick={() => { setDegree(d.id); setCourse(null); setSelectedSubjects([]); }}
              className={`p-4 rounded-lg border-2 text-left transition-all ${
                degree === d.id
                  ? 'border-secondary bg-secondary/10 shadow-card'
                  : 'border-border hover:border-secondary/50'
              }`}
            >
              <span className="text-sm font-medium text-foreground">{d.name}</span>
            </button>
          ))}
        </div>
      </div>

      {/* Course filter */}
      {degree && courses.length > 1 && (
        <div className="mb-6">
          <label className="text-sm font-semibold text-foreground mb-2 block">Curso</label>
          <div className="flex gap-2">
            <button
              onClick={() => setCourse(null)}
              className={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${
                course === null ? 'bg-primary text-primary-foreground' : 'bg-muted text-muted-foreground hover:bg-muted/80'
              }`}
            >
              Todos
            </button>
            {courses.map(c => (
              <button
                key={c}
                onClick={() => setCourse(c)}
                className={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${
                  course === c ? 'bg-primary text-primary-foreground' : 'bg-muted text-muted-foreground hover:bg-muted/80'
                }`}
              >
                {c}º Curso
              </button>
            ))}
          </div>
        </div>
      )}

      {/* Subjects */}
      {degree && (
        <div className="mb-8">
          <label className="text-sm font-semibold text-foreground mb-3 block">
            Asignaturas disponibles
            {selectedSubjects.length > 0 && (
              <Badge className="ml-2 bg-secondary text-secondary-foreground">{selectedSubjects.length} seleccionadas</Badge>
            )}
          </label>
          <div className="space-y-2">
            {filteredSubjects.map(subject => {
              const selected = !!selectedSubjects.find(s => s.id === subject.id);
              const hasLab = subject.groups.some(g => g.type === 'lab');
              return (
                <button
                  key={subject.id}
                  onClick={() => toggleSubject(subject)}
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
          </div>
        </div>
      )}

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
