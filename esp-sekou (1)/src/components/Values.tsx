import { motion } from "motion/react";
import { Heart } from "lucide-react";

const VALUES = [
  ["L'excellence", "l'humilité"],
  ["L'amour", "la bienveillance"],
  ["La solidarité", "la tolérance"],
  ["Le respect", "la considération"],
  ["Le courage", "la patience"],
  ["La paix", "la tranquillité"],
  ["La joie", "l'espérance"],
  ["La volonté", "la rigueur"],
  ["La justice", "la vérité"],
  ["L'unité", "la communion fraternelle"]
];

export default function Values() {
  return (
    <div className="max-w-4xl mx-auto py-6 md:py-12 px-4">
      <header className="text-center mb-10 md:mb-16">
        <motion.div 
          initial={{ scale: 0 }}
          animate={{ scale: 1 }}
          className="w-12 h-12 md:w-16 md:h-16 bg-rose-50 text-rose-500 rounded-full flex items-center justify-center mx-auto mb-4 md:mb-6 shadow-sm"
        >
          <Heart size={24} className="md:size-8" fill="currentColor" />
        </motion.div>
        <h1 className="text-2xl md:text-3xl font-bold text-slate-800 tracking-tight mb-2 uppercase">Valeurs Fondamentales</h1>
        <p className="text-slate-400 text-xs md:text-sm font-bold uppercase tracking-widest tracking-widest leading-loose">Le socle de notre identité polytechnicienne.</p>
      </header>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-x-12 gap-y-12 md:gap-y-16">
        {VALUES.map(([v1, v2], idx) => (
          <motion.div
            key={idx}
            initial={{ opacity: 0, x: -10 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true }}
            transition={{ delay: idx * 0.05 }}
            className="flex flex-col relative"
          >
            <span className="absolute -top-6 -left-3 md:-top-10 md:-left-6 text-6xl md:text-8xl font-bold text-slate-50 select-none z-0">
              {String(idx + 1).padStart(2, '0')}
            </span>
            <div className="relative z-10 pl-6 border-l-4 border-slate-200 hover:border-slate-800 transition-colors">
              <h2 className="text-xl md:text-2xl font-bold text-slate-800 tracking-tight leading-snug">
                {v1} <span className="text-slate-400 font-light lowercase">et</span> <br className="hidden md:block" /> {v2}
              </h2>
              <p className="mt-2 text-[9px] text-slate-400 font-bold uppercase tracking-[0.2em]">
                Axe {idx + 1}
              </p>
            </div>
          </motion.div>
        ))}
      </div>

      <footer className="mt-16 md:mt-24 text-center p-8 md:p-12 rounded-3xl md:rounded-[40px] border relative overflow-hidden transition-all bg-slate-900 text-white shadow-2xl">
        <div className="absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-blue-500 via-rose-500 to-amber-500"></div>
        <div className="absolute inset-0 opacity-10">
           <img src="https://res.cloudinary.com/dkpqkwjgo/image/upload/v1779016358/esp_sekou_logo_nobg_yh1xt7.png" alt="" className="w-64 h-64 absolute -right-10 -bottom-10 rotate-12" />
        </div>
        <p className="text-lg md:text-2xl font-bold italic uppercase tracking-[0.3em] relative z-10 text-slate-300">
          "<span className="text-2xl md:text-4xl text-blue-400 font-black">E</span>xcellence dans la <span className="text-2xl md:text-4xl text-blue-400 font-black">S</span>olidarité et le <span className="text-2xl md:text-4xl text-blue-400 font-black">P</span>artage"
        </p>
      </footer>
    </div>
  );
}
