import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import StepLanding from '@/components/steps/StepLanding';
import StepSelection from '@/components/steps/StepSelection';
import StepPreferences from '@/components/steps/StepPreferences';
import { ProfessorPreferences } from '@/components/steps/StepPreferences';
import StepResults from '@/components/steps/StepResults';
import StepSummary from '@/components/steps/StepSummary';
import { Subject, TimeBlock } from '@/data/demoData';
import { ChosenSemesterSchedule } from '@/lib/semesterSchedules';

const STEP_LABELS = ['Inicio', 'Asignaturas', 'Preferencias', 'Resultados', 'Resumen'];

const Index = () => {
  const [step, setStep] = useState(0);
  const [degree, setDegree] = useState('');
  const [selectedSubjects, setSelectedSubjects] = useState<Subject[]>([]);
  const [blockedTimes, setBlockedTimes] = useState<TimeBlock[]>([]);
  const [professorPrefs, setProfessorPrefs] = useState<ProfessorPreferences>({});
  const [chosenSchedules, setChosenSchedules] = useState<ChosenSemesterSchedule[]>([]);

  const next = () => setStep(s => Math.min(s + 1, 4));
  const prev = () => setStep(s => Math.max(s - 1, 0));
  const restart = () => {
    setStep(0);
    setDegree('');
    setSelectedSubjects([]);
    setBlockedTimes([]);
    setProfessorPrefs({});
<<<<<<< HEAD
    setChosenSchedules([]);
=======
    setChosenSchedule(null);
>>>>>>> 79fd0255223fc5fd76f0cc4655bea2873e8a72bb
  };

  return (
    <div className="min-h-screen bg-background">
      {/* Progress bar */}
      {step > 0 && (
        <div className="sticky top-0 z-50 bg-card/80 backdrop-blur-md border-b border-border">
          <div className="max-w-4xl mx-auto px-4 py-3">
            <div className="flex items-center justify-between mb-2">
              {STEP_LABELS.map((label, i) => (
                <div key={label} className="flex items-center">
                  <button
                    type="button"
                    onClick={() => i <= step && setStep(i)}
                    disabled={i > step}
                    aria-label={`Ir a ${label}`}
                    aria-current={i === step ? 'step' : undefined}
                    className={`w-7 h-7 rounded-full flex items-center justify-center text-xs font-semibold transition-colors ${
                      i <= step
                        ? 'bg-primary text-primary-foreground cursor-pointer hover:opacity-80'
                        : 'bg-muted text-muted-foreground cursor-not-allowed'
                    }`}
                  >
                    {i + 1}
                  </button>
                  <span
                    onClick={() => i <= step && setStep(i)}
                    className={`ml-1.5 text-xs font-medium hidden sm:inline ${
                      i <= step ? 'text-foreground/70 cursor-pointer hover:text-foreground' : 'text-foreground/40 cursor-not-allowed'
                    }`}
                  >
                    {label}
                  </span>
                  {i < STEP_LABELS.length - 1 && (
                    <div className={`w-8 sm:w-16 h-0.5 mx-2 ${i < step ? 'bg-primary' : 'bg-border'}`} />
                  )}
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* Step content */}
      <AnimatePresence mode="wait">
        <motion.div
          key={step}
          initial={{ opacity: 0, x: 30 }}
          animate={{ opacity: 1, x: 0 }}
          exit={{ opacity: 0, x: -30 }}
          transition={{ duration: 0.3, ease: 'easeInOut' }}
        >
          {step === 0 && <StepLanding onStart={next} />}
          {step === 1 && (
            <StepSelection
              degree={degree}
              setDegree={setDegree}
              selectedSubjects={selectedSubjects}
              setSelectedSubjects={setSelectedSubjects}
              onNext={next}
              onBack={prev}
            />
          )}
          {step === 2 && (
            <StepPreferences
              blockedTimes={blockedTimes}
              setBlockedTimes={setBlockedTimes}
              selectedSubjects={selectedSubjects}
              professorPrefs={professorPrefs}
              setProfessorPrefs={setProfessorPrefs}
              onNext={next}
              onBack={prev}
            />
          )}
          {step === 3 && (
            <StepResults
              subjects={selectedSubjects}
              blockedTimes={blockedTimes}
              professorPrefs={professorPrefs}
              onChoose={(schedules) => {
                setChosenSchedules(schedules);
                next();
              }}
              onBack={prev}
            />
          )}
<<<<<<< HEAD
          {step === 4 && chosenSchedules.length > 0 && (
            <StepSummary schedules={chosenSchedules} blockedTimes={blockedTimes} onBack={prev} onRestart={restart} />
=======
          {step === 4 && chosenSchedule && (
            <StepSummary schedule={chosenSchedule} blockedTimes={blockedTimes} onBack={prev} onRestart={restart} />
>>>>>>> 79fd0255223fc5fd76f0cc4655bea2873e8a72bb
          )}
        </motion.div>
      </AnimatePresence>
    </div>
  );
};

export default Index;
