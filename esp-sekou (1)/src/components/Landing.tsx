import { useEffect, useState } from "react";
import { motion, AnimatePresence } from "motion/react";

interface LandingProps {
  onComplete: () => void;
}

export default function Landing({ onComplete }: LandingProps) {
  const [step, setStep] = useState(0);

  useEffect(() => {
    const timers = [
      setTimeout(() => setStep(1), 2000), // Show first message
      setTimeout(() => setStep(2), 6000), // Show Wolof question
      setTimeout(() => onComplete(), 11000) // Complete
    ];
    return () => timers.forEach(clearTimeout);
  }, [onComplete]);

  return (
    <div className="fixed inset-0 bg-slate-50 flex flex-col items-center justify-center z-50 p-6 overflow-hidden">
      <AnimatePresence mode="wait">
        {step === 0 && (
          <motion.div
            key="logo"
            initial={{ opacity: 0, scale: 0.8 }}
            animate={{ opacity: 1, scale: 1 }}
            exit={{ opacity: 0, scale: 1.1 }}
            className="flex flex-col items-center"
          >
            <img 
              src="https://res.cloudinary.com/dkpqkwjgo/image/upload/v1779016358/esp_sekou_logo_nobg_yh1xt7.png" 
              alt="ESP Sekou" 
              className="w-48 h-48 md:w-64 md:h-64 object-contain mb-8"
            />
            <h1 className="text-3xl font-bold tracking-[0.3em] text-slate-800 uppercase">ESP Sekou</h1>
          </motion.div>
        )}

        {step === 1 && (
          <motion.div
            key="intro"
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -20 }}
            className="text-center max-w-2xl"
          >
            <h2 className="text-4xl md:text-5xl font-bold text-slate-900 tracking-tight leading-tight">
              Promotion ESP 2026
            </h2>
            <p className="mt-6 text-xl text-slate-500 font-medium uppercase tracking-[0.2em]">
               <span className="text-3xl font-black text-blue-600">E</span>xcellence dans la <span className="text-3xl font-black text-blue-600">S</span>olidarité et le <span className="text-3xl font-black text-blue-600">P</span>artage
            </p>
          </motion.div>
        )}

        {step === 2 && (
          <motion.div
            key="wolof"
            initial={{ opacity: 0, scale: 0.9 }}
            animate={{ opacity: 1, scale: 1 }}
            exit={{ opacity: 0, scale: 1.1 }}
            transition={{ duration: 1.5, ease: "easeOut" }}
            className="text-center px-4"
          >
            <h2 className="text-4xl md:text-6xl font-black font-serif uppercase tracking-tighter text-slate-800 leading-[1.1] max-w-4xl mx-auto">
              "DUT 1 EST CE QUE KHAMANTE NGEN SEN BIRR ?"
            </h2>
          </motion.div>
        )}
      </AnimatePresence>
      
      <div className="absolute bottom-12 w-48 h-1 bg-slate-200 rounded-full overflow-hidden">
        <motion.div 
          className="h-full bg-blue-600"
          initial={{ width: 0 }}
          animate={{ width: "100%" }}
          transition={{ duration: 11, ease: "linear" }}
        />
      </div>
    </div>
  );
}
