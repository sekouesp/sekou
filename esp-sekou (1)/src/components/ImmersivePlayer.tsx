import { useState, useEffect, useRef } from "react";
import { motion, AnimatePresence } from "motion/react";
import { X, Play, Pause, Volume2, VolumeX, Maximize2, Minimize2, Music } from "lucide-react";
import { cn } from "../lib/utils";
import { getDeptTheme } from "../lib/theme";

interface Sound {
  id: string;
  name: string;
  url: string;
  type: "communal" | "department";
  department?: string;
  lyrics?: string[];
}

interface ImmersivePlayerProps {
  sound: Sound;
  onClose: () => void;
  autoPlay?: boolean;
}

export default function ImmersivePlayer({ sound, onClose, autoPlay = true }: ImmersivePlayerProps) {
  const [isPlaying, setIsPlaying] = useState(autoPlay);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const [volume, setVolume] = useState(0.8);
  const [isMuted, setIsMuted] = useState(false);
  const [isFullscreen, setIsFullscreen] = useState(false);
  const audioRef = useRef<HTMLAudioElement | null>(null);
  
  // Web Audio API refs
  const audioContextRef = useRef<AudioContext | null>(null);
  const analyserRef = useRef<AnalyserNode | null>(null);
  const sourceRef = useRef<MediaElementAudioSourceNode | null>(null);
  
  // Waveform bars
  const [bars, setBars] = useState<number[]>(Array.from({ length: 40 }, () => 5));
  const rafRef = useRef<number>(0);

  const theme = sound.type === 'department' ? getDeptTheme(sound.department || "") : { bg: "bg-slate-900", text: "text-white", border: "border-slate-800" };

  useEffect(() => {
    if (audioRef.current) {
      audioRef.current.volume = isMuted ? 0 : volume;
      if (isPlaying) {
        
        // Initialize Web Audio API on first play
        if (!audioContextRef.current) {
          try {
            audioContextRef.current = new (window.AudioContext || (window as any).webkitAudioContext)();
            analyserRef.current = audioContextRef.current.createAnalyser();
            analyserRef.current.fftSize = 128; // lower for fewer bars
            sourceRef.current = audioContextRef.current.createMediaElementSource(audioRef.current);
            sourceRef.current.connect(analyserRef.current);
            analyserRef.current.connect(audioContextRef.current.destination);
          } catch (e) {
            console.error("Web Audio API setup failed", e);
          }
        }

        if (audioContextRef.current?.state === 'suspended') {
          audioContextRef.current.resume();
        }

        audioRef.current.play().catch(e => {
          console.error("Autoplay prevented:", e);
          setIsPlaying(false);
        });
      } else {
        audioRef.current.pause();
      }
    }
  }, [isPlaying, volume, isMuted]);

  useEffect(() => {
    const updateWaveform = () => {
      if (isPlaying && analyserRef.current) {
        const dataArray = new Uint8Array(analyserRef.current.frequencyBinCount);
        analyserRef.current.getByteFrequencyData(dataArray);
        
        // Take a subset (40 bars) and compute percentage 0-100
        const step = Math.floor(dataArray.length / 40);
        const newBars = Array.from({ length: 40 }).map((_, i) => {
           const val = dataArray[i * step] || 0;
           return Math.max(5, (val / 255) * 100);
        });
        setBars(newBars);
      } else if (!isPlaying) {
        setBars(prev => prev.map(v => Math.max(5, v * 0.9))); // smooth decay
      }
      rafRef.current = requestAnimationFrame(updateWaveform);
    };
    rafRef.current = requestAnimationFrame(updateWaveform);
    
    return () => {
      if (rafRef.current) cancelAnimationFrame(rafRef.current);
    };
  }, [isPlaying]);

  const handleTimeUpdate = () => {
    if (audioRef.current) {
      setCurrentTime(audioRef.current.currentTime);
      setDuration(audioRef.current.duration || 0);
    }
  };

  const toggleFullscreen = () => {
    if (!document.fullscreenElement) {
      document.documentElement.requestFullscreen().catch(e => console.error(e));
      setIsFullscreen(true);
    } else {
      if (document.exitFullscreen) {
        document.exitFullscreen();
        setIsFullscreen(false);
      }
    }
  };

  useEffect(() => {
    const handleFullscreenChange = () => {
      setIsFullscreen(!!document.fullscreenElement);
    };
    document.addEventListener("fullscreenchange", handleFullscreenChange);
    return () => document.removeEventListener("fullscreenchange", handleFullscreenChange);
  }, []);

  const lyrics = sound.lyrics || [];

  return (
    <motion.div 
      initial={{ opacity: 0, y: 100, scale: 0.9 }}
      animate={{ opacity: 1, y: 0, scale: 1 }}
      exit={{ opacity: 0, y: 100, scale: 0.9 }}
      transition={{ type: "spring", damping: 25, stiffness: 200 }}
      className="fixed inset-0 z-[100] flex flex-col bg-slate-950 overflow-hidden"
    >
      <audio 
        ref={audioRef}
        src={sound.url}
        crossOrigin="anonymous"
        onTimeUpdate={handleTimeUpdate}
        onEnded={() => setIsPlaying(false)}
        onLoadedMetadata={handleTimeUpdate}
      />

      {/* Dynamic Background */}
      <div className="absolute inset-0 overflow-hidden mix-blend-screen opacity-40">
        {sound.type === 'communal' ? (
          <>
            <motion.div animate={{ rotate: 360 }} transition={{ duration: 50, repeat: Infinity, ease: "linear" }} className="absolute -top-[20%] -left-[10%] w-[70vw] h-[70vw] bg-rose-500/30 blur-[120px] rounded-full" />
            <motion.div animate={{ rotate: -360 }} transition={{ duration: 60, repeat: Infinity, ease: "linear" }} className="absolute top-[30%] -right-[20%] w-[80vw] h-[80vw] bg-blue-500/30 blur-[120px] rounded-full" />
            <motion.div animate={{ rotate: 180 }} transition={{ duration: 40, repeat: Infinity, ease: "linear" }} className="absolute -bottom-[20%] left-[20%] w-[60vw] h-[60vw] bg-emerald-500/30 blur-[120px] rounded-full" />
            <motion.div animate={{ rotate: -180 }} transition={{ duration: 55, repeat: Infinity, ease: "linear" }} className="absolute -bottom-[10%] -right-[10%] w-[70vw] h-[70vw] bg-amber-500/30 blur-[120px] rounded-full" />
          </>
        ) : (
          <>
            <motion.div animate={{ rotate: 360, scale: [1, 1.2, 1] }} transition={{ duration: 20, repeat: Infinity, ease: "easeInOut" }} className={cn("absolute -top-[10%] -left-[10%] w-[60vw] h-[60vw] blur-[140px] rounded-full opacity-50", theme.bg)} />
            <motion.div animate={{ rotate: -360, scale: [1, 1.5, 1] }} transition={{ duration: 25, repeat: Infinity, ease: "easeInOut" }} className={cn("absolute bottom-[10%] -right-[10%] w-[70vw] h-[70vw] blur-[150px] rounded-full opacity-40", theme.bg)} />
          </>
        )}
      </div>

      <div className="relative z-10 flex flex-col h-full">
        {/* Header */}
        <header className="flex items-center justify-between p-6 md:p-8 shrink-0 relative z-20">
           <div className="flex items-center gap-4">
              <button onClick={onClose} className="p-3 bg-white/5 hover:bg-white/10 text-white rounded-full backdrop-blur-md transition-all active:scale-90">
                 <X size={24} />
              </button>
              <div>
                 <h2 className="text-xl md:text-2xl font-black text-white tracking-tight">{sound.name}</h2>
                 <p className="text-[10px] md:text-xs font-bold text-white/50 uppercase tracking-[0.2em]">{sound.department || "Hymne Communal"}</p>
              </div>
           </div>
           
           <div className="flex items-center gap-4">
              <div className="hidden md:flex items-center gap-3 bg-white/5 p-2 rounded-full backdrop-blur-md">
                <button onClick={() => setIsMuted(!isMuted)} className="p-2 text-white/50 hover:text-white transition-colors">
                  {isMuted ? <VolumeX size={18} /> : <Volume2 size={18} />}
                </button>
                <input 
                  type="range" 
                  min="0" max="1" step="0.01" 
                  value={volume}
                  onChange={(e) => setVolume(parseFloat(e.target.value))}
                  className="w-24 accent-white mr-3"
                />
              </div>
              
              {document.fullscreenEnabled && (
                <button onClick={toggleFullscreen} className="p-3 bg-white/5 hover:bg-white/10 text-white rounded-full backdrop-blur-md transition-all">
                  {isFullscreen ? <Minimize2 size={20} /> : <Maximize2 size={20} />}
                </button>
              )}
           </div>
        </header>

        {/* Lyrics Area (Scrollable) */}
        <div className="grow overflow-y-auto mt-4 px-4 md:px-16 pt-10 pb-[30vh] z-10 scrollbar-hide">
           <div className="w-full max-w-4xl mx-auto flex flex-col items-center">
              {lyrics.length > 0 ? (
                <div className="w-full space-y-6 md:space-y-8 flex flex-col items-center text-center">
                   {lyrics.map((line, i) => (
                     <motion.p 
                       key={i}
                       initial={{ opacity: 0, y: 20 }}
                       animate={{ opacity: 1, y: 0 }}
                       transition={{ delay: i * 0.05 }}
                       className="text-2xl md:text-4xl lg:text-5xl font-black text-white/90 tracking-tighter w-full leading-tight drop-shadow-[0_0_10px_rgba(255,255,255,0.2)]"
                     >
                        {line}
                     </motion.p>
                   ))}
                </div>
              ) : (
                <div className="flex flex-col items-center justify-center space-y-4 my-auto h-full min-h-[40vh]">
                  <div className="w-24 h-24 rounded-full bg-white/5 border-2 border-white/10 flex items-center justify-center text-white/30 backdrop-blur-md">
                     <Music size={48} />
                  </div>
                  <p className="text-white/40 font-medium text-lg uppercase tracking-widest text-[10px]">Aucune parole disponible</p>
                </div>
              )}
           </div>
        </div>

        {/* Bottom Controls / Waveform */}
        <div className="absolute bottom-0 inset-x-0 z-20 pointer-events-none">
           {/* Visualizer */}
           <div className="h-16 md:h-24 flex items-end justify-center gap-1 md:gap-2 px-4 mb-24 md:mb-28 opacity-80 mix-blend-screen pointer-events-none">
              {bars.map((bar, i) => (
                <motion.div 
                  key={i}
                  animate={{ height: `${bar}%` }}
                  transition={{ type: "tween", ease: "linear", duration: 0.05 }}
                  className={cn(
                    "w-1 md:w-2 rounded-full shadow-[0_0_15px_rgba(255,255,255,0.4)]",
                    sound.type === 'communal' ? "bg-white/80" : theme.bg.replace("bg-", "bg-").replace("-50", "-400") // Approximation for color if we just use a generic class. Safer to just use white based. Let's stick to white for elegance.
                  )}
                  style={{ backgroundColor: 'rgba(255,255,255,0.8)' }}
                />
              ))}
           </div>
           
           {/* Scrubber & Controls */}
           <div className="absolute bottom-0 inset-x-0 h-32 bg-gradient-to-t from-slate-950 via-slate-950/80 to-transparent flex flex-col justify-end pb-8 px-6 md:px-12 pointer-events-auto">
              <div className="max-w-4xl w-full mx-auto flex items-center gap-6">
                 <button 
                   onClick={() => setIsPlaying(!isPlaying)}
                   className="w-14 h-14 shrink-0 rounded-full bg-white text-slate-950 flex items-center justify-center hover:scale-105 transition-all shadow-[0_0_30px_rgba(255,255,255,0.3)]"
                 >
                   {isPlaying ? <Pause size={24} fill="currentColor" /> : <Play size={24} fill="currentColor" className="ml-1" />}
                 </button>
                 
                 <div className="grow flex flex-col gap-2">
                    <div 
                      className="h-1.5 w-full bg-white/10 rounded-full cursor-pointer relative group overflow-hidden"
                      onClick={(e) => {
                        if (!audioRef.current) return;
                        const rect = e.currentTarget.getBoundingClientRect();
                        const pos = (e.clientX - rect.left) / rect.width;
                        audioRef.current.currentTime = pos * duration;
                      }}
                    >
                       <div 
                         className="absolute inset-y-0 left-0 bg-white shadow-[0_0_10px_rgba(255,255,255,0.5)] rounded-full transition-all duration-100 ease-linear"
                         style={{ width: `${duration ? (currentTime / duration) * 100 : 0}%` }}
                       />
                    </div>
                    <div className="flex items-center justify-between text-[10px] font-mono text-white/50">
                       <span>{Math.floor(currentTime / 60)}:{(Math.floor(currentTime % 60)).toString().padStart(2, '0')}</span>
                       <span>{Math.floor(duration / 60)}:{(Math.floor(duration % 60)).toString().padStart(2, '0')}</span>
                    </div>
                 </div>
              </div>
           </div>
        </div>
      </div>
    </motion.div>
  );
}
