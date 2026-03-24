import { motion } from 'framer-motion';
import { GraduationCap, Clock, Sparkles, ArrowRight } from 'lucide-react';
import { Button } from '@/components/ui/button';

interface StepLandingProps {
  onStart: () => void;
}

const features = [
  { icon: Clock, title: 'Ahorra tiempo', desc: 'Genera tu horario ideal en minutos, no en horas.' },
  { icon: GraduationCap, title: 'Sin solapamientos', desc: 'Detectamos conflictos automáticamente.' },
  { icon: Sparkles, title: 'Personalizado', desc: 'Respeta tus restricciones de trabajo y transporte.' },
];

const StepLanding = ({ onStart }: StepLandingProps) => {
  return (
    <div className="min-h-screen flex flex-col">
      {/* Hero */}
      <section className="gradient-hero text-primary-foreground py-20 px-4 flex-shrink-0">
        <div className="max-w-3xl mx-auto text-center">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.1 }}
          >
            <div className="inline-flex items-center gap-2 bg-secondary/20 rounded-full px-4 py-1.5 mb-6 text-sm font-medium text-gold-light">
              <Sparkles className="w-4 h-4" />
              Planifica tu matrícula sin estrés
            </div>
          </motion.div>

          <motion.h1
            className="font-display text-4xl sm:text-5xl md:text-6xl font-bold mb-6 leading-tight"
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.2 }}
          >
            Tu horario perfecto,{' '}
            <span className="text-gold">en minutos</span>
          </motion.h1>

          <motion.p
            className="text-lg sm:text-xl opacity-85 mb-10 max-w-xl mx-auto leading-relaxed"
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.3 }}
          >
            Selecciona tus asignaturas, marca tus restricciones y obtén múltiples
            opciones de horario sin solapamientos ni huecos muertos.
          </motion.p>

          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.4 }}
          >
            <Button
              onClick={onStart}
              size="lg"
              className="gradient-gold text-primary font-semibold text-lg px-8 py-6 rounded-xl hover:opacity-90 transition-opacity shadow-elevated"
            >
              Comenzar
              <ArrowRight className="ml-2 w-5 h-5" />
            </Button>
          </motion.div>
        </div>
      </section>

      {/* Features */}
      <section className="py-16 px-4 flex-1">
        <div className="max-w-4xl mx-auto grid md:grid-cols-3 gap-8">
          {features.map((f, i) => (
            <motion.div
              key={f.title}
              className="bg-card rounded-xl p-6 shadow-card border border-border text-center"
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.5 + i * 0.1 }}
            >
              <div className="w-12 h-12 rounded-full bg-secondary/20 flex items-center justify-center mx-auto mb-4">
                <f.icon className="w-6 h-6 text-secondary" />
              </div>
              <h3 className="font-display text-lg font-semibold mb-2 text-foreground">{f.title}</h3>
              <p className="text-sm text-muted-foreground leading-relaxed">{f.desc}</p>
            </motion.div>
          ))}
        </div>
      </section>
    </div>
  );
};

export default StepLanding;
