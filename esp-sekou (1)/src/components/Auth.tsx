import { useState } from "react";
import { auth } from "../firebase";
import { GoogleAuthProvider, signInWithPopup } from "firebase/auth";
import { motion, AnimatePresence } from "motion/react";
import { LogIn } from "lucide-react";
import { PARROT_IMAGES } from "../lib/parrots";

const ParrotImage = ({ src, index }: { src: string; index: number }) => {
  const [loaded, setLoaded] = useState(false);

  return (
    <div className="break-inside-avoid relative rounded-2xl overflow-hidden border border-white/20 shadow-md mb-4 bg-slate-200/50" style={{ minHeight: "120px" }}>
      <AnimatePresence>
        {!loaded && (
          <motion.div 
             exit={{ opacity: 0 }}
             className="absolute inset-0 bg-slate-300/40 animate-pulse flex items-center justify-center backdrop-blur-sm"
          >
             <div className="w-8 h-8 border-4 border-slate-300 border-t-white rounded-full animate-spin shadow-[0_0_15px_rgba(255,255,255,0.5)]"></div>
          </motion.div>
        )}
      </AnimatePresence>
      <img 
        src={src} 
        alt="Background Parrot" 
        className={`w-full h-auto object-cover transition-opacity duration-700 ${loaded ? 'opacity-100' : 'opacity-0'}`}
        onLoad={() => setLoaded(true)}
      />
    </div>
  );
};

export default function Auth() {
  const handleGoogleSignIn = async () => {
    const provider = new GoogleAuthProvider();
    try {
      await signInWithPopup(auth, provider);
    } catch (error) {
      console.error("Auth error:", error);
    }
  };

  return (
    <div className="relative min-h-screen bg-slate-100 flex items-center justify-center overflow-hidden">
      {/* Infinite Scrolling Background Grid */}
      <div className="absolute inset-0 z-0 flex items-center justify-center pointer-events-none w-full h-[200vh]">
        <motion.div 
          animate={{ y: ["0%", "-50%"] }}
          transition={{ duration: 60, repeat: Infinity, ease: "linear" }}
          className="w-full flex flex-col gap-4"
        >
          {[1, 2].map((wrap) => (
            <div key={wrap} className="columns-2 sm:columns-3 md:columns-4 lg:columns-5 xl:columns-6 gap-4 space-y-4 w-full px-4 opacity-50">
              {PARROT_IMAGES.map((src, i) => (
                <ParrotImage key={`img-${wrap}-${i}`} src={src} index={i} />
              ))}
            </div>
          ))}
        </motion.div>
      </div>
      
      {/* Gradient Overlay to ensure readability */}
      <div className="absolute inset-0 bg-gradient-to-t from-slate-100/70 via-slate-100/20 to-transparent pointer-events-none z-0"></div>

      {/* Central Login Card */}
      <motion.div 
        initial={{ opacity: 0, scale: 0.9, y: 30 }}
        animate={{ opacity: 1, scale: 1, y: 0 }}
        transition={{ type: "spring", stiffness: 150, damping: 15, delay: 0.2 }}
        className="relative z-10 max-w-xs w-full mx-6 bg-white/40 backdrop-blur-xl rounded-[2.5rem] p-8 shadow-[0_8px_32px_rgba(0,0,0,0.1)] flex flex-col items-center text-center border border-white/40"
      >
        <motion.div 
           initial={{ rotate: -180, scale: 0 }}
           animate={{ rotate: 0, scale: 1 }}
           transition={{ type: "spring", stiffness: 200, damping: 20, delay: 0.4 }}
           className="p-4 bg-white/60 backdrop-blur-md rounded-2xl mb-6 shadow-sm border border-white/50"
        >
          <img 
            src="https://res.cloudinary.com/dkpqkwjgo/image/upload/v1779016358/esp_sekou_logo_nobg_yh1xt7.png" 
            alt="ESP Sekou" 
            className="w-16 h-16 object-contain drop-shadow-sm"
          />
        </motion.div>
        
        <motion.h1 
           initial={{ opacity: 0, y: 10 }}
           animate={{ opacity: 1, y: 0 }}
           transition={{ delay: 0.6 }}
           className="text-xl font-black text-slate-800 tracking-[0.25em] uppercase mb-8 w-full pb-4 border-b border-slate-400/20"
        >
          ESP SEKOU
        </motion.h1>

        <motion.button
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.8 }}
          whileHover={{ scale: 1.05 }}
          whileTap={{ scale: 0.95 }}
          onClick={handleGoogleSignIn}
          className="w-full flex items-center justify-center gap-3 bg-slate-900/90 backdrop-blur-md text-white border border-slate-800 py-4 px-6 rounded-2xl hover:bg-slate-800 transition-all font-bold shadow-xl shadow-slate-900/10 group cursor-pointer pointer-events-auto"
        >
          <LogIn size={18} className="text-white/80 group-hover:text-white transition-colors" />
          <span className="text-sm tracking-[0.15em] uppercase">Connexion</span>
        </motion.button>
      </motion.div>
    </div>
  );
}
