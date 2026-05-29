import React, { useState } from "react";
import { motion, AnimatePresence } from "motion/react";
import { cn } from "../lib/utils";

const getCommissionTheme = (name: string) => {
  const n = name.toLowerCase();
  if (n.includes("it")) return { icon: "terminal", color: "#3B82F6" }; // blue-500
  if (n.includes("sponsor") || n.includes("partenariat")) return { icon: "handshake", color: "#F59E0B" }; // amber-500
  if (n.includes("pédagogique") || n.includes("pedagogique")) return { icon: "menu_book", color: "#10B981" }; // emerald-500
  if (n.includes("culturel") || n.includes("fetes") || n.includes("fêtes")) return { icon: "palette", color: "#A855F7" }; // purple-500
  if (n.includes("sport")) return { icon: "sports_soccer", color: "#F97316" }; // orange-500
  if (n.includes("comm") || n.includes("presse")) return { icon: "campaign", color: "#F43F5E" }; // rose-500
  return { icon: "group", color: "#64748B" }; // slate-500
};

export default function WhatsAppAnimatedButton({ commission, href }: { commission: string, href: string }) {
  const [isRedirecting, setIsRedirecting] = useState(false);
  const theme = getCommissionTheme(commission);

  const handleClick = (e: React.MouseEvent) => {
    e.preventDefault();
    setIsRedirecting(true);
    setTimeout(() => {
      window.open(href, "_blank", "noopener,noreferrer");
      setIsRedirecting(false);
    }, 4500); // Wait for the animation to play out
  };

  return (
    <>
      <button 
        onClick={handleClick}
        className="flex items-center gap-2 bg-white hover:bg-slate-50 px-4 py-2 rounded-xl text-xs font-bold text-slate-700 shadow-[0_4px_12px_rgba(0,0,0,0.05)] transition-all hover:shadow-[0_4px_16px_rgba(0,0,0,0.1)] hover:-translate-y-0.5"
      >
        <img src="https://res.cloudinary.com/dkpqkwjgo/image/upload/v1773944021/WhatsApp_qyvy28.svg" className="w-5 h-5" alt="WhatsApp" />
        Rejoindre {commission}
      </button>

      <AnimatePresence>
        {isRedirecting && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-[100] flex items-center justify-center overflow-hidden bg-slate-900/95 backdrop-blur-md"
          >
             {/* Background Particles with 12 Principles of Animation vibes */}
             {/* Squashing and Stretching, Follow through floating */}
             {[...Array(12)].map((_, i) => (
               <motion.div
                 key={`bg-icon-${i}`}
                 className="absolute text-7xl opacity-20 material-symbols-rounded select-none"
                 style={{ color: theme.color }}
                 initial={{ 
                   opacity: 0, 
                   scale: 0.2, 
                   x: (Math.random() - 0.5) * window.innerWidth * 1.5, 
                   y: (Math.random() - 0.5) * window.innerHeight * 1.5,
                   rotate: Math.random() * 360
                 }}
                 animate={{ 
                   opacity: [0, 0.5, 0],
                   scale: [0.2, 1.5 + Math.random(), 0.5],
                   y: `+=${(Math.random() - 0.5) * 300}`,
                   x: `+=${(Math.random() - 0.5) * 300}`,
                   rotate: `+=${(Math.random() - 0.5) * 180}`
                 }}
                 transition={{
                   duration: 3 + Math.random() * 2,
                   ease: "easeInOut",
                   delay: Math.random() * 1.5
                 }}
               >
                 {theme.icon}
               </motion.div>
             ))}

            <div className="relative flex flex-col items-center justify-center w-80 h-80">
              
              {/* 1. First Message (Pops out top right) - Anticipation & Overshoot */}
              <motion.div
                initial={{ opacity: 0, scale: 0.2, x: 0, y: 0, rotate: -20 }}
                animate={{ opacity: 1, scale: 1, x: 80, y: -90, rotate: 0 }}
                transition={{ duration: 0.7, delay: 0.5, ease: [0.34, 1.56, 0.64, 1] }}
                className="absolute bg-[#25D366] text-white px-4 py-3 rounded-2xl rounded-bl-none shadow-2xl text-sm z-20 font-bold tracking-tight whitespace-nowrap"
              >
                Salut ! Tu rejoins {commission} ? 👋
              </motion.div>

              {/* 2. Reply Message (Pops out bottom left) */}
              <motion.div
                initial={{ opacity: 0, scale: 0.2, x: 0, y: 0, rotate: 20 }}
                animate={{ opacity: 1, scale: 1, x: -90, y: 80, rotate: 0 }}
                transition={{ duration: 0.7, delay: 1.5, ease: [0.34, 1.56, 0.64, 1] }}
                className="absolute bg-white text-slate-800 px-4 py-3 rounded-2xl rounded-br-none shadow-2xl text-sm z-20 font-bold tracking-tight whitespace-nowrap"
              >
                Oui, let's go ! 🚀
              </motion.div>

              {/* 3. Typing indicator (Pops out bottom right) */}
              <motion.div
                initial={{ opacity: 0, scale: 0.2, x: 0, y: 0 }}
                animate={{ opacity: 1, scale: 1, x: 100, y: 40 }}
                transition={{ duration: 0.6, delay: 2.5, ease: "backOut" }}
                className="absolute bg-[#25D366] text-white px-5 py-4 rounded-2xl rounded-bl-none shadow-2xl z-20 flex flex-col items-center justify-center gap-1 min-w-[70px]"
              >
                <div className="flex items-center gap-1.5">
                   <motion.div animate={{ y: [0, -5, 0] }} transition={{ repeat: Infinity, duration: 0.6, delay: 0 }} className="w-1.5 h-1.5 bg-white/90 rounded-full" />
                   <motion.div animate={{ y: [0, -5, 0] }} transition={{ repeat: Infinity, duration: 0.6, delay: 0.2 }} className="w-1.5 h-1.5 bg-white/90 rounded-full" />
                   <motion.div animate={{ y: [0, -5, 0] }} transition={{ repeat: Infinity, duration: 0.6, delay: 0.4 }} className="w-1.5 h-1.5 bg-white/90 rounded-full" />
                </div>
              </motion.div>

              {/* 4. Main Central Floating Icon */}
              <motion.div
                 // Squash and stretch entrance
                initial={{ scale: 0, scaleY: 2, scaleX: 0.2, rotate: -180, opacity: 0 }}
                animate={{ scale: 1, scaleY: 1, scaleX: 1, rotate: 0, opacity: 1 }}
                transition={{ type: "spring", bounce: 0.7, duration: 1.2, delay: 0.1 }}
                className="relative z-30"
              >
                <motion.div
                  // Continuous hover
                  animate={{ y: [0, -12, 0] }}
                  transition={{ repeat: Infinity, duration: 2.5, ease: "easeInOut" }}
                  className="bg-white rounded-full p-6 shadow-[0_0_40px_rgba(37,211,102,0.4)] flex items-center justify-center"
                >
                   <img src="https://res.cloudinary.com/dkpqkwjgo/image/upload/v1773944021/WhatsApp_qyvy28.svg" className="w-16 h-16 relative z-10" alt="WhatsApp" />
                </motion.div>
              </motion.div>
              
              <motion.p
                 initial={{ opacity: 0, y: 10 }}
                 animate={{ opacity: 1, y: 0 }}
                 transition={{ delay: 3 }}
                 className="absolute -bottom-16 text-white/80 font-black tracking-[0.25em] text-xs uppercase"
              >
                 Ouverture de WhatsApp...
              </motion.p>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </>
  );
}
