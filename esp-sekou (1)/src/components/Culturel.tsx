import { useState, useEffect } from "react";
import { UserProfile, AppConfig } from "../App";
import { db } from "../firebase";
import { collection, onSnapshot, query, orderBy } from "firebase/firestore";
import { motion, AnimatePresence } from "motion/react";
import { 
  Play, 
  Music, 
  Library,
  Waves
} from "lucide-react";
import { cn } from "../lib/utils";
import { getDeptTheme } from "../lib/theme";
import ImmersivePlayer from "./ImmersivePlayer";

interface CulturelProps {
  profile: UserProfile;
  config: AppConfig;
}

interface Sound {
  id: string;
  name: string;
  url: string;
  type: "communal" | "department";
  department?: string;
  createdAt: any;
  lyrics?: string[];
}

export default function Culturel({ profile, config }: CulturelProps) {
  const [sounds, setSounds] = useState<Sound[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedSound, setSelectedSound] = useState<Sound | null>(null);

  const theme = getDeptTheme(profile.department);

  useEffect(() => {
    const q = query(collection(db, "culturel_sounds"), orderBy("createdAt", "desc"));
    const unsub = onSnapshot(q, (snap) => {
      setSounds(snap.docs.map(doc => ({ id: doc.id, ...doc.data() } as Sound)));
      setLoading(false);
    });
    return () => unsub();
  }, []);

  const communalSounds = sounds.filter(s => s.type === "communal");
  const departmentSounds = sounds.filter(s => s.type === "department");

  // Group department sounds by department
  const groupedDepts = departmentSounds.reduce((acc, sound) => {
    const dept = sound.department || "Inconnu";
    if (!acc[dept]) acc[dept] = [];
    acc[dept].push(sound);
    return acc;
  }, {} as Record<string, Sound[]>);

  return (
    <>
      <AnimatePresence>
        {selectedSound && (
          <ImmersivePlayer key="player" sound={selectedSound} onClose={() => setSelectedSound(null)} />
        )}
      </AnimatePresence>

      <div className="space-y-12 pb-32">
        <header className="relative py-16 px-8 rounded-[40px] overflow-hidden bg-slate-900 text-white shadow-2xl">
         {/* Abstract Background */}
         <div className="absolute inset-0 opacity-20">
            <div className="absolute top-0 right-0 w-96 h-96 bg-blue-500 blur-[120px] rounded-full -translate-y-1/2 translate-x-1/2"></div>
            <div className="absolute bottom-0 left-0 w-96 h-96 bg-indigo-500 blur-[120px] rounded-full translate-y-1/2 -translate-x-1/2"></div>
         </div>
         
         <div className="relative z-10 max-w-2xl">
            <p className="text-[10px] font-black uppercase tracking-[0.5em] text-blue-400 mb-4">Patrimoine Immatériel</p>
            <h1 className="text-4xl md:text-6xl font-black tracking-tighter mb-6 italic leading-[0.9]">CULTURE <span className="text-transparent bg-clip-text bg-gradient-to-r from-blue-400 to-indigo-400 font-light underline decoration-blue-500/50 underline-offset-8">POLYTECH</span></h1>
            <p className="text-slate-400 text-sm md:text-base font-medium leading-relaxed">
              Explorez l'identité sonore de l'ESP. Des cris de guerre des départements à l'hymne de l'unité, chaque son porte l'âme de notre promotion. Cliquez sur un son pour lancer l'expérience immersive.
            </p>
         </div>
      </header>

      {/* Communal Section */}
      <section className="space-y-6">
        <div className="flex items-center gap-3 px-4">
           <Library className={cn("shrink-0", theme.text)} size={20} />
           <h2 className="text-sm font-black uppercase tracking-[0.2em] text-slate-800">Sons de l'École</h2>
           <div className="h-px grow bg-slate-200"></div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
           {communalSounds.map((sound, i) => (
             <motion.div
               initial={{ opacity: 0, y: 20 }}
               animate={{ opacity: 1, y: 0 }}
               transition={{ delay: i * 0.05 }}
               key={sound.id}
               className="group relative bg-white p-6 rounded-[32px] border border-slate-200 shadow-sm hover:shadow-xl hover:shadow-slate-200/50 transition-all cursor-pointer"
               onClick={() => setSelectedSound(sound)}
             >
                <div className="flex flex-col items-center text-center space-y-4">
                   <div className="relative">
                      <div className="w-20 h-20 rounded-full flex items-center justify-center transition-all duration-500 bg-slate-50 group-hover:bg-slate-100">
                         <img 
                          src={config.communalLogo || "https://res.cloudinary.com/dkpqkwjgo/image/upload/v1779016358/esp_sekou_logo_nobg_yh1xt7.png"} 
                          className="w-12 h-12 object-contain opacity-80" 
                          alt=""
                         />
                      </div>
                   </div>
                   
                   <div>
                      <h4 className="text-sm font-black text-slate-800 tracking-tight">{sound.name}</h4>
                      <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest mt-1">Communal</p>
                   </div>

                   <div className="w-10 h-10 rounded-full flex items-center justify-center transition-all bg-slate-900 text-white opacity-0 group-hover:opacity-100 translate-y-2 group-hover:translate-y-0">
                      <Play size={16} className="ml-0.5" fill="currentColor" />
                   </div>
                </div>
             </motion.div>
           ))}
        </div>
      </section>

      {/* Department Sections */}
      {Object.entries(groupedDepts).map(([dept, deptSounds], di) => (
        <section key={dept} className="space-y-6">
          <div className="flex items-center gap-3 px-4">
             <Waves className="shrink-0 text-slate-400" size={20} />
             <h2 className="text-sm font-black uppercase tracking-[0.2em] text-slate-800">{dept}</h2>
             <div className="h-px grow bg-slate-200"></div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
             {deptSounds.map((sound, i) => (
               <motion.div
                 initial={{ opacity: 0, y: 20 }}
                 whileInView={{ opacity: 1, y: 0 }}
                 viewport={{ once: true }}
                 transition={{ delay: i * 0.05 }}
                 key={sound.id}
                 className="group relative bg-white p-6 rounded-[32px] border border-slate-200 shadow-sm hover:shadow-xl hover:shadow-slate-200/50 transition-all cursor-pointer"
                 onClick={() => setSelectedSound(sound)}
               >
                  <div className="flex flex-col items-center text-center space-y-4">
                     <div className="relative">
                        <div className="w-20 h-20 rounded-full flex items-center justify-center transition-all duration-500 bg-slate-50 group-hover:bg-slate-100">
                           <img 
                            src={(config.departmentLogos as any)?.[dept] || "https://res.cloudinary.com/dkpqkwjgo/image/upload/v1779016358/esp_sekou_logo_nobg_yh1xt7.png"} 
                            className="w-12 h-12 object-contain opacity-80" 
                            alt=""
                           />
                        </div>
                     </div>
                     
                     <div>
                        <h4 className="text-sm font-black text-slate-800 tracking-tight">{sound.name}</h4>
                        <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest mt-1">{dept}</p>
                     </div>

                     <div className="w-10 h-10 rounded-full flex items-center justify-center transition-all bg-slate-900 text-white opacity-0 group-hover:opacity-100 translate-y-2 group-hover:translate-y-0">
                        <Play size={16} className="ml-0.5" fill="currentColor" />
                     </div>
                  </div>
               </motion.div>
             ))}
          </div>
        </section>
      ))}

      {sounds.length === 0 && !loading && (
        <div className="flex flex-col items-center justify-center py-20 text-center space-y-4">
           <div className="w-16 h-16 bg-slate-100 rounded-full flex items-center justify-center text-slate-300">
              <Music size={32} />
           </div>
           <p className="text-slate-400 font-medium">Aucun son dans le répertoire pour le moment.</p>
        </div>
      )}
    </div>
    </>
  );
}
