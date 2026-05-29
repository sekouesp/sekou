import { motion } from "motion/react";
import { ArrowLeft, MapPin, Sparkles, MessageCircle, ShieldCheck, Heart, User, Flag, Calendar, GraduationCap, Trophy, Award } from "lucide-react";
import { UserProfile, AppConfig } from "../App";
import { cn } from "../lib/utils";
import { getDeptTheme } from "../lib/theme";

interface PublicProfileProps {
  user: UserProfile;
  viewerProfile: UserProfile;
  config: AppConfig;
  onBack: () => void;
  onMessage: (user: UserProfile) => void;
}

export default function PublicProfile({ user, viewerProfile, config, onBack, onMessage }: PublicProfileProps) {
  const theme = getDeptTheme(user.department);
  const showRankingData = config.rankingEnabled || viewerProfile.role !== 'user';

  return (
    <div className="max-w-4xl mx-auto pb-20 relative">
      {/* Floating Back Button */}
      <div className="sticky top-6 left-0 z-50 pointer-events-none mb-4">
        <button 
          onClick={onBack}
          className="pointer-events-auto p-3.5 bg-white shadow-2xl rounded-2xl text-slate-800 hover:scale-110 transition-all border border-slate-100 active:scale-95 group flex items-center gap-2"
        >
          <ArrowLeft size={20} className="group-hover:-translate-x-1 transition-transform" />
          <span className="text-xs font-black uppercase tracking-[0.2em] pr-1">Retour</span>
        </button>
      </div>

      {/* Header / Cover area */}
      <div className="relative mb-24 mt-8 md:-mt-20">
        <div className={cn("h-48 md:h-64 rounded-[40px] shadow-inner relative overflow-hidden", theme.gradient)}>
           <div className="absolute inset-0 opacity-20">
              <img src="https://res.cloudinary.com/dkpqkwjgo/image/upload/v1779016358/esp_sekou_logo_nobg_yh1xt7.png" alt="" className="w-96 h-96 absolute -right-20 -bottom-20 rotate-12" />
           </div>
        </div>

        {/* Profile Info Overlay */}
        <div className="absolute -bottom-16 left-4 right-4 md:left-8 md:right-8 flex flex-col md:flex-row items-center md:items-end gap-4 md:gap-6 text-center md:text-left">
           <div className="relative group">
              <div className={cn("absolute -inset-1 rounded-[40px] blur-xl opacity-40 animate-pulse", theme.bg)}></div>
              <div className="relative w-28 h-28 md:w-40 md:h-40 rounded-[38px] overflow-hidden border-4 border-white shadow-2xl bg-white">
                 <img 
                   src={user.photoUrl || "https://ui-avatars.com/api/?name=" + user.firstName} 
                   alt="" 
                   className="w-full h-full object-cover"
                 />
              </div>
           </div>

           <div className="flex-1 pb-2">
              <div className="flex flex-wrap items-center justify-center md:justify-start gap-3 mb-1">
                 <h1 className="text-2xl md:text-5xl font-black text-slate-800 tracking-tight flex items-center gap-3">
                   {user.firstName} {user.lastName}
                 </h1>
              </div>
              <div className="flex flex-wrap items-center justify-center md:justify-start gap-4 text-slate-500 font-bold uppercase tracking-widest text-[9px] md:text-xs">
                 <div className="flex items-center gap-1.5 px-3 py-1 bg-slate-100 rounded-full">
                    <GraduationCap size={14} className={theme.text} />
                    {user.department}
                 </div>
              </div>
           </div>

           <button 
             onClick={() => onMessage(user)}
             className={cn("mb-2 px-8 py-4 rounded-3xl text-white font-bold flex items-center gap-3 shadow-xl transition-all hover:scale-105 active:scale-95", theme.bg, theme.shadow)}
           >
             <MessageCircle size={20} /> Message
           </button>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8 px-4 md:px-0">
        {/* Left Column: Details */}
        <div className="lg:col-span-2 space-y-8">
           <section className="bg-white rounded-[40px] p-8 md:p-10 border border-slate-100 shadow-sm">
              <h3 className="text-xs font-black text-slate-400 uppercase tracking-[0.3em] mb-6 flex items-center gap-2">
                 <User size={16} className={theme.text} /> Biographie
              </h3>
              <p className="text-slate-700 text-lg md:text-xl leading-relaxed italic font-medium">
                 "{user.bio || "Pas encore de bio. Cet étudiant préfère laisser son talent parler pour lui."}"
              </p>
           </section>

           {user.commissions && user.commissions.length > 0 && (
             <section className="bg-white rounded-[40px] p-8 md:p-10 border border-slate-100 shadow-sm">
                <h3 className="text-xs font-black text-slate-400 uppercase tracking-[0.3em] mb-6 flex items-center gap-2">
                   <Flag size={16} className={theme.text} /> Commissions rejointes
                </h3>
                <div className="flex flex-wrap gap-4">
                  {user.commissions.map((comm, i) => (
                    <motion.div 
                      key={i}
                      initial={{ opacity: 0, scale: 0.9 }}
                      animate={{ opacity: 1, scale: 1 }}
                      transition={{ delay: i * 0.1 }}
                      className={cn("px-6 py-3 rounded-2xl text-xs font-black uppercase tracking-widest border transition-all", theme.lightBg, theme.text, "border-transparent hover:border-current")}
                    >
                      {comm}
                    </motion.div>
                  ))}
                </div>
             </section>
           )}

           <section className="bg-white rounded-[40px] p-8 md:p-10 border border-slate-100 shadow-sm">
              <h3 className="text-xs font-black text-slate-400 uppercase tracking-[0.3em] mb-6 flex items-center gap-2">
                 <Heart size={16} className={theme.text} /> Centres d'intérêt
              </h3>
              <p className="text-slate-600 leading-relaxed font-bold">
                 {user.hobbies || "En cours de découverte..."}
              </p>
           </section>
        </div>

        {/* Right Column: Mini Stats/Info */}
        <div className="space-y-6">
           <div className={cn("rounded-[40px] p-8 border text-white relative overflow-hidden", theme.bg)}>
              <div className="absolute top-0 right-0 p-4 opacity-10">
                 <Sparkles size={120} />
              </div>
              <h4 className="text-[10px] font-black uppercase tracking-[0.4em] opacity-60 mb-8 underline decoration-wavy">Statut Académique</h4>
              <div className="space-y-6 relative z-10">
                 <div>
                    <p className="text-[8px] font-bold uppercase opacity-50 mb-1">Département</p>
                    <p className="font-black uppercase tracking-tight text-lg">{user.department}</p>
                 </div>
              </div>
           </div>

           {showRankingData && (
             <div className="bg-slate-900 rounded-[40px] p-8 text-white relative overflow-hidden">
                <div className="absolute -bottom-10 -right-10 opacity-5 rotate-12">
                   <img src="https://res.cloudinary.com/dkpqkwjgo/image/upload/v1779016358/esp_sekou_logo_nobg_yh1xt7.png" alt="" className="w-48 h-48" />
                </div>
                <h4 className="text-[10px] font-black uppercase tracking-[0.4em] text-slate-500 mb-6 flex items-center gap-2">
                  <Trophy size={14} /> Score & Engagement
                </h4>
                <div className="space-y-6">
                  <div className="flex items-center gap-4">
                     <div className="w-14 h-14 rounded-2xl bg-white/10 flex items-center justify-center text-amber-500">
                        <Sparkles size={24} />
                     </div>
                     <div>
                        <p className="text-sm font-black text-white">{user.interactionStats?.points || 0} Points</p>
                        <p className="text-[9px] text-slate-400 font-bold uppercase tracking-widest">Engagement Global</p>
                     </div>
                  </div>
                  
                  <div className="grid grid-cols-2 gap-4">
                    <div className="bg-white/5 p-3 rounded-2xl border border-white/5">
                      <p className="text-[8px] font-bold text-slate-400 uppercase mb-1">Messages</p>
                      <p className="font-bold text-sm tracking-tighter">{user.interactionStats?.totalMessages || 0}</p>
                    </div>
                    <div className="bg-white/5 p-3 rounded-2xl border border-white/5">
                      <p className="text-[8px] font-bold text-slate-400 uppercase mb-1">Contacts</p>
                      <p className="font-bold text-sm tracking-tighter">{user.interactionStats?.startedConversations || 0}</p>
                    </div>
                  </div>

                  {user.interactionStats?.crossDeptInteractions && user.interactionStats.crossDeptInteractions.length >= 3 && (
                    <div className="flex items-center gap-2 p-3 bg-indigo-500/20 rounded-2xl border border-indigo-500/20 text-indigo-400">
                      <Award size={16} />
                      <span className="text-[10px] font-black uppercase tracking-widest leading-none">Ambassadeur</span>
                    </div>
                  )}
                </div>
              </div>
           )}
        </div>
      </div>
    </div>
  );
}
