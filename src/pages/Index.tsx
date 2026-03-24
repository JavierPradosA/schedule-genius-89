import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import StepLanding from '@/components/steps/StepLanding';
import StepSelection from '@/components/steps/StepSelection';
import StepPreferences from '@/components/steps/StepPreferences';
import StepResults from '@/components/steps/StepResults';
import StepSummary from '@/components/steps/StepSummary';
import { Subject, TimeBlock } from '@/data/demoData';
import { ScheduleOption } from '@/lib/scheduleGenerator';

const STEP_LABELS = ['Inicio', 'Asignaturas', 'Preferencias', 'Resultados', 'Resumen'];

const Index = () => {
  const [step, setStep] = useState(0);
  const [degree, setDegree] = useState('');
  const [selectedSubjects, setSelectedSubjects] = useState<Subject[]>([]);
  const [blockedTimes, setBlockedTimes] = useState<TimeBlock[]>([]);
  const [chosenSchedule, setChosenSchedule] = useState<ScheduleOption | null>(null);

  const next = () => setStep(s => Math.min(s + 1, 4));
  const prev = () => setStep(s => Math.max(s - 1, 0));

  return (
    <div className="min-h-screen bg-background">
      {/* Progress bar */}
      {step > 0 && (
        <div className="sticky top-0 z-50 bg-card/80 backdrop-blur-md border-b border-border">
          <div className="max-w-4xl mx-auto px-4 py-3">
            <div className="flex items-center justify-between mb-2">
              {STEP_LABELS.map((label, i) => (
                <div key={label} className="flex items-center">
                  <div
                    className={`w-7 h-7 rounded-full flex items-center justify-center text-xs font-semibold transition-colors ${
                      i <= step
                        ? 'bg-primary text-primary-foreground'
                        : 'bg-muted text-muted-foreground'
                    }`}
                  >
                    {i + 1}
                  </div>
                  <span className="ml-1.5 text-xs font-medium hidden sm:inline text-foreground/70">
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
              onNext={next}
              onBack={prev}
            />
          )}
          {step === 3 && (
            <StepResults
              subjects={selectedSubjects}
              blockedTimes={blockedTimes}
              onChoose={(schedule) => {
                setChosenSchedule(schedule);
                next();
              }}
              onBack={prev}
            />
          )}
          {step === 4 && chosenSchedule && (
            <StepSummary schedule={chosenSchedule} onBack={prev} onRestart={() => setStep(0)} />
          )}
        </motion.div>
      </AnimatePresence>
    </div>
  );
};

export default Index;
