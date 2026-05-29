import React, { useState, useRef, useEffect } from "react";
import { motion, AnimatePresence } from "motion/react";
import { PARROT_IMAGES, PARROT_SOUNDS } from "../lib/parrots";
import { Bird, X, Play, Pause, Volume2, Link2, Download } from "lucide-react";

export default function ParrotMuseum() {
  const [selectedImage, setSelectedImage] = useState<string | null>(null);
  const [playingSound, setPlayingSound] = useState<number | null>(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const audioRefs = useRef<(HTMLAudioElement | null)[]>([]);

  useEffect(() => {
    // Fill refs
    audioRefs.current = audioRefs.current.slice(0, PARROT_SOUNDS.length);
  }, []);

  useEffect(() => {
    if (playingSound !== null) {
       const audio = audioRefs.current[playingSound];
       if (!audio) return;
       
       const handleTimeUpdate = () => setCurrentTime(audio.currentTime);
       const handleLoadedMetadata = () => setDuration(audio.duration);
       const handlePlay = () => setIsPlaying(true);
       const handlePause = () => setIsPlaying(false);
       
       audio.addEventListener('timeupdate', handleTimeUpdate);
       audio.addEventListener('loadedmetadata', handleLoadedMetadata);
       audio.addEventListener('play', handlePlay);
       audio.addEventListener('pause', handlePause);
       
       setDuration(audio.duration || 0);
       setCurrentTime(audio.currentTime || 0);
       setIsPlaying(!audio.paused);

       return () => {
          audio.removeEventListener('timeupdate', handleTimeUpdate);
          audio.removeEventListener('loadedmetadata', handleLoadedMetadata);
          audio.removeEventListener('play', handlePlay);
          audio.removeEventListener('pause', handlePause);
       };
    }
  }, [playingSound]);

  const formatTime = (time: number) => {
    if (isNaN(time)) return "00:00";
    const m = Math.floor(time / 60);
    const s = Math.floor(time % 60);
    return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  };

  const handleSeek = (e: React.MouseEvent<HTMLDivElement>) => {
    if (playingSound === null) return;
    const audio = audioRefs.current[playingSound];
    if (!audio) return;
    
    const rect = e.currentTarget.getBoundingClientRect();
    const percent = (e.clientX - rect.left) / rect.width;
    audio.currentTime = percent * duration;
  };

  const toggleSound = (index: number) => {
    audioRefs.current.forEach((audio, i) => {
       if (audio && i !== index) {
          audio.pause();
       }
    });
    
    const nextAudio = audioRefs.current[index];
    if (playingSound === index) {
       if (nextAudio && nextAudio.paused) {
           nextAudio.play();
       } else if (nextAudio) {
           nextAudio.pause();
       }
    } else {
       if (nextAudio) {
          nextAudio.currentTime = 0;
          nextAudio.play();
       }
       setPlayingSound(index);
    }
  };

  const togglePlayPauseCurrent = () => {
    if (playingSound === null) return;
    const audio = audioRefs.current[playingSound];
    if (!audio) return;
    
    if (audio.paused) {
       audio.play();
    } else {
       audio.pause();
    }
  };

  return (
    <div className="relative min-h-[calc(100vh-5rem)] bg-slate-50 p-4 md:p-8 space-y-8 pb-32">
      {/* Header & Sounds */}
      <div className="flex flex-col md:flex-row items-center justify-between gap-6 bg-white p-6 rounded-3xl border border-slate-100 shadow-sm relative overflow-hidden">
         <div className="absolute -right-10 -top-10 opacity-5 pointer-events-none">
            <img src="https://res.cloudinary.com/dkpqkwjgo/image/upload/v1779726055/flying_parrot_ks37nf.png" className="w-64 h-64 object-contain" alt="Parrot Background" />
         </div>
         <div className="flex items-center gap-4 relative z-10">
            <div className="p-3 bg-teal-50/50 rounded-2xl w-16 h-16 flex items-center justify-center shrink-0">
               <img src="https://res.cloudinary.com/dkpqkwjgo/image/upload/v1779726055/flying_parrot_ks37nf.png" className="w-12 h-12 object-contain" alt="Parrot Logo" />
            </div>
            <div>
               <h1 className="text-2xl font-black text-slate-800 tracking-tight">Le Musée des Perroquets</h1>
               <p className="text-slate-500 font-medium text-sm">Découvrez nos compagnons en images et en sons.</p>
            </div>
         </div>
         
         {/* Audio Player Controls */}
         <div className="flex flex-wrap items-center gap-3 relative z-10">
            <div className="flex items-center gap-2 mr-2 text-slate-400">
               <Volume2 size={16} />
               <span className="text-[10px] uppercase font-bold tracking-widest">Ambiance Sonore</span>
            </div>
            {PARROT_SOUNDS.map((sound, index) => (
               <div key={index}>
                 <audio 
                   ref={el => { audioRefs.current[index] = el; }}
                   src={sound.url} 
                   loop 
                   preload="none"
                 />
                 <button
                   onClick={() => toggleSound(index)}
                   className={`flex items-center justify-center gap-2 px-4 py-2 rounded-xl text-xs font-bold transition-all shadow-sm active:scale-95 ${
                     playingSound === index 
                       ? "bg-[#25D366] text-white shadow-[#25D366]/20" 
                       : "bg-slate-100 text-slate-600 hover:bg-slate-200"
                   }`}
                 >
                   {playingSound === index && isPlaying ? <Pause size={14} /> : <Play size={14} />}
                   {sound.name}
                 </button>
               </div>
            ))}
         </div>
      </div>

      {/* Masonry Grid */}
      <div className="columns-1 sm:columns-2 md:columns-3 lg:columns-4 gap-6 space-y-6">
        {PARROT_IMAGES.map((src, index) => (
          <motion.div
            key={index}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: index * 0.05, duration: 0.5 }}
            className="break-inside-avoid relative rounded-2xl overflow-hidden cursor-zoom-in group shadow-sm border border-slate-200 bg-white"
            onClick={() => setSelectedImage(src)}
          >
            <div className="absolute inset-0 bg-slate-900/0 group-hover:bg-slate-900/20 transition-colors z-10 flex items-center justify-center">
               <div className="bg-white/90 backdrop-blur-sm p-3 rounded-full opacity-0 group-hover:opacity-100 transition-all transform scale-50 group-hover:scale-100">
                  <Bird className="text-teal-600" size={24} />
               </div>
            </div>
            <img 
              src={src} 
              alt={`Parrot ${index}`} 
              className="w-full h-auto object-cover group-hover:scale-105 transition-transform duration-500"
              loading="lazy"
            />
          </motion.div>
        ))}
      </div>

      {/* Floating Audio Player */}
      <AnimatePresence>
        {playingSound !== null && (
          <motion.div 
            initial={{ y: 100, opacity: 0, x: "-50%" }}
            animate={{ y: 0, opacity: 1, x: "-50%" }}
            exit={{ y: 100, opacity: 0, x: "-50%" }}
            transition={{ type: "spring", stiffness: 260, damping: 20 }}
            className="fixed bottom-8 left-1/2 z-40 w-full max-w-md px-4"
          >
            <div className="bg-[#fcfaf8] border border-slate-200 rounded-[2rem] px-5 py-4 flex items-center gap-4 shadow-[0_8px_30px_rgba(0,0,0,0.08)] w-full relative">
              
              <button 
                onClick={togglePlayPauseCurrent} 
                className="w-12 h-12 shrink-0 bg-white rounded-full flex items-center justify-center shadow-sm border border-slate-100 hover:scale-105 active:scale-95 transition-all text-slate-800"
              >
                {isPlaying ? <Pause size={20} className="fill-current" /> : <Play size={20} className="fill-current ml-1" />}
              </button>

              <div className="flex-1 min-w-[150px]">
                 <h4 className="text-sm font-semibold text-slate-800 mb-1.5 truncate">
                   Parrot {PARROT_SOUNDS[playingSound].name.toLowerCase()}
                 </h4>
                 <div className="flex items-center gap-3">
                    <span className="text-[10px] text-slate-500 font-medium w-8 shrink-0">{formatTime(currentTime)}</span>
                    <div 
                      className="h-1.5 flex-1 bg-slate-200 rounded-full relative cursor-pointer group" 
                      onClick={handleSeek}
                    >
                        <div 
                          className="absolute top-0 left-0 h-full bg-slate-800 rounded-full transition-all duration-100 ease-linear" 
                          style={{ width: `${duration > 0 ? (currentTime / duration) * 100 : 0}%` }} 
                        />
                        <div 
                          className="absolute top-1/2 -translate-y-1/2 w-2.5 h-2.5 bg-slate-800 rounded-full opacity-0 group-hover:opacity-100 transition-opacity"
                          style={{ left: `calc(${duration > 0 ? (currentTime / duration) * 100 : 0}% - 5px)` }}
                        />
                    </div>
                    <span className="text-[10px] text-slate-500 font-medium w-8 shrink-0 text-right">{formatTime(duration)}</span>
                 </div>
              </div>

              <div className="flex items-center gap-1 shrink-0 text-slate-500 ml-2">
                 <button className="p-2 hover:bg-slate-200/50 rounded-full transition-colors active:bg-slate-200 focus:outline-none focus:ring-2 focus:ring-slate-300">
                    <Link2 size={18} />
                 </button>
                 <button className="p-2 hover:bg-slate-200/50 rounded-full transition-colors active:bg-slate-200 focus:outline-none focus:ring-2 focus:ring-slate-300" title="Download">
                    <a href={PARROT_SOUNDS[playingSound].url} download target="_blank" rel="noopener noreferrer">
                      <Download size={18} />
                    </a>
                 </button>
              </div>

            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Fullscreen Overlay */}
      <AnimatePresence>
        {selectedImage && (
          <motion.div 
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/90 backdrop-blur-sm p-4"
            onClick={() => setSelectedImage(null)}
          >
            <div className="absolute top-6 right-6 z-50">
               <button 
                 onClick={() => setSelectedImage(null)}
                 className="p-3 bg-white/10 hover:bg-white/20 rounded-full text-white backdrop-blur-md transition-colors"
               >
                 <X size={24} />
               </button>
            </div>
            
            <motion.img 
              initial={{ scale: 0.9, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.9, opacity: 0 }}
              transition={{ type: "spring", damping: 25, stiffness: 300 }}
              src={selectedImage} 
              alt="Fullscreen Parrot" 
              className="max-w-full max-h-[90vh] object-contain rounded-2xl shadow-2xl"
              onClick={(e) => e.stopPropagation()} // Prevent closing when clicking the image itself
            />
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
