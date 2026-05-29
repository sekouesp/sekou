import { motion } from "motion/react";
import { BookOpen, Quote } from "lucide-react";
import { cn } from "../lib/utils";

const OATH_LINES = [
  "Je jure d'obéir à mes anciens",
  "En tout ce qui concerne le travail auquel je suis appelé",
  "Et dans l'exercice de mes devoirs.",
  "Je jure egalement de ne faire usage de mes connaissances",
  "Que pour la réussite de tout polytechnicien.",
  "Il faut être conscient que dans la compétition",
  "L'ambition individuelle sert le bien commun.",
  "Mais le meilleur résultat arrive",
  "Lorsque chacun fait ce qui est bon pour lui et pour le groupe",
  "."
];

export default function Oath() {
  return (
    <div className="max-w-2xl mx-auto py-6 md:py-12 px-4">
      <header className="text-center mb-10 md:mb-16">
        <motion.div 
          initial={{ y: -20, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          className="w-12 h-12 md:w-16 md:h-16 bg-slate-900 text-white rounded-2xl flex items-center justify-center mx-auto mb-4 md:mb-6 shadow-xl shadow-slate-900/10 rotate-3"
        >
          <BookOpen size={24} className="md:size-8" />
        </motion.div>
        <h1 className="text-3xl md:text-4xl font-bold text-slate-800 tracking-tighter mb-1 md:mb-2 uppercase">Le Serment</h1>
        <p className="text-slate-400 uppercase tracking-[0.4em] text-[8px] md:text-[10px] font-bold">Polytechnicien</p>
      </header>

      <div className="bg-slate-900 rounded-3xl md:rounded-[48px] p-6 md:p-16 shadow-2xl shadow-slate-900/40 border-4 border-slate-800 relative overflow-hidden group">
        <Quote size={80} className="absolute -top-4 -left-4 text-white/5 opacity-40 -z-0 group-hover:scale-110 transition-transform duration-1000" />
        
        <div className="relative z-10 space-y-4 md:space-y-6 text-center">
          {OATH_LINES.map((line, idx) => (
            <motion.p
              key={idx}
              initial={{ opacity: 0, y: 10 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: idx * 0.1 }}
              className={cn(
                "font-bold tracking-tight leading-relaxed italic transition-colors",
                line === "." ? "text-3xl md:text-5xl text-amber-500 pt-6" : "text-base md:text-xl text-slate-300 group-hover:text-white"
              )}
            >
              {line === "." ? "•" : line}
            </motion.p>
          ))}
        </div>

        <div className="absolute -bottom-12 -right-12 opacity-[0.05] pointer-events-none group-hover:rotate-12 transition-transform duration-1000">
           <img src="https://res.cloudinary.com/dkpqkwjgo/image/upload/v1779016358/esp_sekou_logo_nobg_yh1xt7.png" alt="" className="w-40 h-40 md:w-80 md:h-80 invert" />
        </div>
      </div>

      <motion.p 
        initial={{ opacity: 0 }}
        whileInView={{ opacity: 1 }}
        className="mt-8 md:mt-12 text-center text-slate-400 text-[10px] md:text-xs font-bold uppercase tracking-widest italic"
      >
        À prononcer lors des rituels d'intégration.
      </motion.p>
    </div>
  );
}
