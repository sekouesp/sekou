import { UserProfile } from "../App";
import { motion, AnimatePresence } from "motion/react";
import { X, MapPin, Sparkles, MessageCircle, ShieldCheck, Heart, User, Flag } from "lucide-react";
import { cn } from "../lib/utils";
import { getDeptTheme } from "../lib/theme";

interface UserDetailModalProps {
  user: UserProfile | null;
  onClose: () => void;
  onStartChat: (user: UserProfile) => void;
  onViewFullProfile: (user: UserProfile) => void;
}

export default function UserDetailModal({ user, onClose, onStartChat, onViewFullProfile }: UserDetailModalProps) {
  if (!user) return null;
  const theme = getDeptTheme(user.department);

  return (
    <AnimatePresence>
      <div className="fixed inset-0 z-[100] flex items-center justify-center p-4">
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          onClick={onClose}
          className="absolute inset-0 bg-slate-900/60 backdrop-blur-md"
        />
        <motion.div
          initial={{ opacity: 0, scale: 0.9, y: 20 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          exit={{ opacity: 0, scale: 0.9, y: 20 }}
          className="relative w-full max-w-lg bg-white rounded-[40px] overflow-hidden shadow-2xl border border-white/20"
        >
          {/* Header/Cover */}
          <div className={cn("h-32 md:h-40 relative", theme.gradient)}>
            <div className="absolute inset-0 opacity-10">
               <img src="https://res.cloudinary.com/dkpqkwjgo/image/upload/v1779016358/esp_sekou_logo_nobg_yh1xt7.png" alt="" className="w-64 h-64 absolute -right-10 -bottom-10 rotate-12" />
            </div>
            <button 
              onClick={onClose}
              className="absolute top-4 right-4 p-2 bg-white/20 hover:bg-white/40 rounded-full text-white transition-all backdrop-blur-md"
            >
              <X size={20} />
            </button>
          </div>

          <div className="px-6 md:px-10 pb-10 -mt-12 md:-mt-16 text-center">
            <div className="relative inline-block mb-6">
              <div className={cn("absolute inset-0 rounded-[38px] blur-xl opacity-20", theme.bg)}></div>
              <div className="relative w-24 h-24 md:w-32 md:h-32 rounded-[35px] overflow-hidden border-4 border-white shadow-xl bg-white">
                 <img 
                   src={user.photoUrl || "https://ui-avatars.com/api/?name=" + user.firstName} 
                   alt="" 
                   className="w-full h-full object-cover" 
                 />
              </div>
              <div className="absolute -bottom-2 -right-2 bg-rose-500 text-white p-2 rounded-2xl shadow-lg border-2 border-white">
                <ShieldCheck size={18} />
              </div>
            </div>

            <div className="space-y-4">
              <div>
                <h2 className="text-2xl md:text-3xl font-black text-slate-800 tracking-tight flex items-center justify-center gap-2 uppercase italic">
                  {user.firstName} {user.lastName}
                </h2>
                <div className="flex items-center justify-center gap-2 mt-2">
                   <span className={cn("px-3 py-1 rounded-full text-[9px] font-bold uppercase tracking-widest", theme.lightBg, theme.text)}>{user.department}</span>
                </div>
              </div>

              <div className="space-y-6 pt-4">
                <div className="relative p-6 rounded-3xl bg-slate-50 border border-slate-100">
                   <h4 className="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-3 text-left">Biographie</h4>
                   <p className="text-slate-600 leading-relaxed font-bold italic text-sm text-left line-clamp-3">
                     "{user.bio || "Prêt à servir l'excellence polytechnicienne !"}"
                   </p>
                </div>
                
                <div className="flex gap-3 pt-2">
                   <button 
                     onClick={() => onStartChat(user)}
                     className={cn("flex-1 px-6 py-4 rounded-2xl text-white font-bold text-sm flex items-center justify-center gap-2 shadow-lg transition-all active:scale-95", theme.bg)}
                   >
                     <MessageCircle size={18} /> Message
                   </button>
                   <button 
                     onClick={() => onViewFullProfile(user)}
                     className="flex-1 px-6 py-4 rounded-2xl bg-slate-900 text-white font-bold text-sm flex items-center justify-center gap-2 shadow-lg transition-all hover:bg-slate-800 active:scale-95"
                   >
                      Voir Plus
                   </button>
                </div>
              </div>

              <div className="mt-8 pt-6 border-t border-slate-100 flex items-center justify-between">
                 <img src="https://res.cloudinary.com/dkpqkwjgo/image/upload/v1779016358/esp_sekou_logo_nobg_yh1xt7.png" alt="ESP" className="h-8 opacity-20 grayscale" />
                 <p className="text-[9px] font-bold text-slate-300 uppercase tracking-widest">ESP Sekou • Solidarité & Partage</p>
              </div>
            </div>
          </div>
        </motion.div>
      </div>
    </AnimatePresence>
  );
}
