import { useState, useEffect } from "react";
import { UserProfile } from "../App";
import { db } from "../firebase";
import { collection, query, orderBy, onSnapshot, where } from "firebase/firestore";
import { motion, AnimatePresence } from "motion/react";
import { Megaphone, Bell, Calendar, ChevronRight } from "lucide-react";
import { format } from "date-fns";
import { fr } from "date-fns/locale";
import { cn } from "../lib/utils";

import { getDeptTheme } from "../lib/theme";

interface Broadcast {
  id: string;
  text: string;
  senderId: string;
  filterDept: string | null;
  createdAt: any;
}

export default function Notifications({ profile }: { profile: UserProfile }) {
  const [broadcasts, setBroadcasts] = useState<Broadcast[]>([]);
  const [loading, setLoading] = useState(true);
  const theme = getDeptTheme(profile.department);

  useEffect(() => {
    const q = query(collection(db, "broadcasts"), orderBy("createdAt", "desc"));
    const unsub = onSnapshot(q, (snap) => {
      const all = snap.docs.map(doc => ({ id: doc.id, ...doc.data() } as Broadcast));
      const filtered = all.filter(b => !b.filterDept || b.filterDept === profile.department);
      setBroadcasts(filtered);
      setLoading(false);
    });
    return unsub;
  }, [profile.department]);

  return (
    <div className="max-w-3xl mx-auto space-y-6 md:space-y-10 pb-10">
      <header className="px-2 md:px-0">
        <div className="flex items-center gap-3 mb-2">
           <div className={cn("p-1.5 rounded-lg", theme.light, theme.text)}>
              <Bell size={18} />
           </div>
           <h2 className="text-[9px] md:text-[10px] font-bold text-slate-400 uppercase tracking-[0.2em]">Flux d'Annonces Bureau</h2>
        </div>
        <h1 className="text-2xl md:text-3xl font-bold text-slate-800 tracking-tight">Espace Notifications</h1>
      </header>

      {loading ? (
        <div className="space-y-4 px-2 md:px-0">
          {[1,2,3].map(i => (
            <div key={i} className="h-24 md:h-32 bg-white/40 rounded-2xl md:rounded-3xl animate-pulse border border-slate-100" />
          ))}
        </div>
      ) : broadcasts.length === 0 ? (
        <div className={cn("flex flex-col items-center justify-center p-12 md:p-20 text-center rounded-3xl md:rounded-[40px] border mx-2 md:mx-0 shadow-sm transition-all", theme.light, "border-"+theme.primary+"-100/30")}>
          <div className="w-16 h-16 bg-white rounded-2xl flex items-center justify-center mb-6 text-slate-200 shadow-xl border border-slate-50">
             <Megaphone size={32} />
          </div>
          <h3 className="text-lg font-bold text-slate-800 tracking-tight">Aucune annonce</h3>
          <p className="text-slate-400 text-xs mt-2 max-w-[200px] font-medium leading-relaxed">Les messages du bureau s'afficheront ici.</p>
        </div>
      ) : (
        <div className="space-y-6 md:space-y-8 px-2 md:px-0">
          <AnimatePresence mode="popLayout">
            {broadcasts.map((b, idx) => (
              <motion.div
                layout
                initial={{ opacity: 0, scale: 0.95 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={{ delay: idx * 0.05 }}
                key={b.id}
                className="bg-white rounded-2xl md:rounded-[40px] p-6 md:p-10 border border-slate-100 shadow-sm hover:shadow-xl hover:-translate-y-1 transition-all group relative overflow-hidden"
              >
                {b.filterDept && (
                  <div className={cn("absolute top-0 right-0 px-4 py-1.5 text-[9px] md:text-[11px] font-extrabold uppercase tracking-widest rounded-bl-2xl shadow-sm z-10", theme.bg, "text-white")}>
                    {b.filterDept}
                  </div>
                )}
                
                <div className="flex flex-col md:flex-row items-start gap-6 md:gap-8">
                  <div className={cn("shrink-0 w-12 h-12 md:w-16 md:h-16 rounded-2xl md:rounded-3xl flex items-center justify-center group-hover:text-white transition-all shadow-lg", theme.light, theme.text, "group-hover:"+theme.bg, "group-hover:scale-110 group-hover:shadow-"+theme.primary+"-200")}>
                    <Megaphone size={24} className="md:size-8" />
                  </div>
                  
                  <div className="flex-1 min-w-0 text-left">
                    <div className="flex items-center gap-2 text-[10px] font-bold text-slate-400 uppercase tracking-[0.2em] mb-3">
                       <Calendar size={14} className={theme.text} />
                       <span>{b.createdAt ? format(b.createdAt.toDate(), "d MMMM yyyy 'à' HH:mm", { locale: fr }) : "Maintenant"}</span>
                    </div>
                    
                    <p className="text-slate-800 leading-relaxed font-bold text-sm md:text-xl break-words italic tracking-tight">
                      "{b.text}"
                    </p>
                    
                    <div className={cn("pt-6 mt-6 border-t flex items-center justify-between", "border-"+theme.primary+"-50/50")}>
                       <div className="flex items-center gap-2">
                          <img src="https://res.cloudinary.com/dkpqkwjgo/image/upload/v1779016358/esp_sekou_logo_nobg_yh1xt7.png" alt="" className="w-5 h-5 opacity-20" />
                          <span className="text-[9px] font-extrabold text-slate-300 uppercase tracking-widest italic">Bureau d'Intégration ESP</span>
                       </div>
                       <button className={cn("flex items-center gap-2 text-[10px] font-extrabold uppercase tracking-[0.2em] group/btn transition-all", theme.text)}>
                          C'est compris <ChevronRight size={14} className="group-hover/btn:translate-x-1 transition-transform" />
                       </button>
                    </div>
                  </div>
                </div>
                <div className={cn("absolute -bottom-10 -right-10 w-32 h-32 opacity-[0.03] transition-opacity group-hover:opacity-[0.06]", theme.text)}>
                   <Bell size={128} />
                </div>
              </motion.div>
            ))}
          </AnimatePresence>
        </div>
      )}
    </div>
  );
}
