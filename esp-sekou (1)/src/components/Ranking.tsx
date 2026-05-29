import { useState, useEffect } from "react";
import { collection, query, orderBy, limit, onSnapshot, where, getDocs } from "firebase/firestore";
import { db } from "../firebase";
import { UserProfile, AppConfig } from "../App";
import { motion, AnimatePresence } from "motion/react";
import { Trophy, Medal, Star, ShieldCheck, MessageCircle, Crown, Info, Award, User } from "lucide-react";
import { cn } from "../lib/utils";
import { getDeptTheme } from "../lib/theme";

interface RankingProps {
  profile: UserProfile;
  config: AppConfig;
  onViewProfile: (user: UserProfile) => void;
}

export default function Ranking({ profile, config, onViewProfile }: RankingProps) {
  const [topUsers, setTopUsers] = useState<UserProfile[]>([]);
  const [loading, setLoading] = useState(true);
  const [bureauCount, setBureauCount] = useState(0);

  useEffect(() => {
    // Get total number of bureau members to calculate "Ambassador" badge status
    const fetchBureauCount = async () => {
      const q = query(collection(db, "users"), where("isBureauMember", "==", true));
      const snap = await getDocs(q);
      setBureauCount(snap.size);
    };
    fetchBureauCount();

    const q = query(
      collection(db, "users"),
      orderBy("interactionStats.points", "desc"),
      limit(config.rankingLimit || 100)
    );

    const unsub = onSnapshot(q, (snap) => {
      const users = snap.docs.map(doc => ({ uid: doc.id, ...doc.data() } as UserProfile));
      // Ensure we only show users who have at least some interaction or stats
      setTopUsers(users.filter(u => u.interactionStats?.points !== undefined && u.role !== 'super-admin'));
      setLoading(false);
    });

    return unsub;
  }, [config.rankingLimit]);

  const getRankStats = (u: UserProfile, index: number) => {
    const stats = u.interactionStats || { points: 0, startedConversations: 0, totalMessages: 0, crossDeptInteractions: [] };
    const hasAmbassador = (stats.crossDeptInteractions?.length || 0) >= 3;
    
    const badges = [];
    if (index === 0) badges.push({ icon: <Crown size={12} />, label: "Major", color: "bg-amber-100 text-amber-700" });
    if (hasAmbassador) badges.push({ icon: <ShieldCheck size={12} />, label: "Ambassadeur", color: "bg-rose-100 text-rose-700" });
    if (stats.startedConversations >= 50) badges.push({ icon: <Award size={12} />, label: "Ultra Connecté", color: "bg-indigo-100 text-indigo-700" });
    else if (stats.startedConversations >= 20) badges.push({ icon: <Award size={12} />, label: "Très Actif", color: "bg-blue-100 text-blue-700" });

    return { stats, badges };
  };

  const theme = getDeptTheme(profile.department);

  return (
    <div className="max-w-4xl mx-auto space-y-8 pb-20">
      {/* Hero Stats */}
      <div className={cn("rounded-[3rem] p-8 md:p-12 text-white relative overflow-hidden shadow-2xl", theme.gradient)}>
        <div className="absolute inset-0 opacity-10">
           <img src="https://res.cloudinary.com/dkpqkwjgo/image/upload/v1779016358/esp_sekou_logo_nobg_yh1xt7.png" alt="" className="w-96 h-96 absolute -right-20 -top-20 -rotate-12" />
        </div>
        
        <div className="relative z-10 flex flex-col md:flex-row items-center gap-8">
           <div className="w-24 h-24 md:w-32 md:h-32 bg-white/20 backdrop-blur-xl rounded-[2.5rem] flex items-center justify-center border border-white/30 shadow-2xl">
              <Trophy size={64} className="text-white drop-shadow-lg" />
           </div>
           <div className="flex-1 text-center md:text-left">
              <h1 className="text-3xl md:text-5xl font-black tracking-tight uppercase italic mb-2">Classement Elite</h1>
              <p className="text-white/80 font-bold uppercase tracking-[0.3em] text-[10px] md:text-xs leading-relaxed">
                Le top {config.rankingLimit} des étudiants les plus connectés de la promotion.
              </p>
              <div className="mt-6 flex flex-wrap justify-center md:justify-start gap-4">
                 <div className="px-4 py-2 bg-white/10 backdrop-blur-md rounded-2xl border border-white/10">
                    <p className="text-[8px] font-bold uppercase opacity-60">Tes Points</p>
                    <p className="text-xl font-black">{profile.interactionStats?.points || 0}</p>
                 </div>
                 <div className="px-4 py-2 bg-white/10 backdrop-blur-md rounded-2xl border border-white/10">
                    <p className="text-[8px] font-bold uppercase opacity-60">Ton Rang</p>
                    <p className="text-xl font-black">#{topUsers.findIndex(u => u.uid === profile.uid) + 1 || "-"}</p>
                 </div>
              </div>
           </div>
        </div>
      </div>

      {/* Info & Dept Summary Grid */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="md:col-span-2 bg-amber-50 border border-amber-100 rounded-3xl p-6 flex gap-4 items-start">
           <div className="p-3 bg-amber-100 text-amber-600 rounded-2xl shrink-0">
              <Info size={20} />
           </div>
           <div className="space-y-1">
              <h4 className="font-bold text-amber-900 text-sm">Comment gagner des points ?</h4>
              <p className="text-[11px] text-amber-700 font-medium leading-relaxed">
                Commencez des conversations (+10 pts) et maintenez-les activement (+1 pt par message). 
                <span className="font-bold"> Bonus x2</span> pour les échanges avec les membres d'autres départements ! Débloquez des badges exclusifs en connectant toute la promotion.
              </p>
           </div>
        </div>

        <div className="bg-indigo-50 border border-indigo-100 rounded-3xl p-6">
           <h4 className="text-[10px] font-black text-indigo-900 uppercase tracking-widest mb-4">Top Départements</h4>
           <div className="space-y-3">
              {Object.entries(
                topUsers.reduce((acc, u) => {
                  acc[u.department] = (acc[u.department] || 0) + (u.interactionStats?.points || 0);
                  return acc;
                }, {} as Record<string, number>)
              )
              .sort((a,b) => b[1]-a[1])
              .slice(0, 3)
              .map(([dept, pts], i) => (
                <div key={dept} className="flex items-center justify-between">
                   <div className="flex items-center gap-2">
                      <span className="text-[10px] font-black text-indigo-400 w-4">#{i+1}</span>
                      <span className="text-[10px] font-bold text-indigo-900 uppercase">{dept}</span>
                   </div>
                   <span className="text-[10px] font-black text-indigo-600">{pts.toLocaleString()}</span>
                </div>
              ))}
           </div>
        </div>
      </div>

      {/* Leaderboard */}
      <div className="bg-white rounded-[2.5rem] border border-slate-100 shadow-sm overflow-hidden">
        <div className="p-6 md:p-10 border-b border-slate-50 flex items-center justify-between">
           <h3 className="text-xs font-black text-slate-400 uppercase tracking-[0.4em]">Classement Général</h3>
           <Star size={16} className="text-amber-400" />
        </div>

        {loading ? (
          <div className="p-20 text-center space-y-4">
             <div className="animate-spin w-8 h-8 border-4 border-[#5A5A40]/20 border-t-[#5A5A40] rounded-full mx-auto" />
             <p className="text-[10px] font-bold text-slate-400 uppercase tracking-[0.2em]">Chargement des données...</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="bg-slate-50/50">
                  <th className="px-6 py-4 text-left text-[9px] font-black text-slate-400 uppercase tracking-widest">Rang</th>
                  <th className="px-6 py-4 text-left text-[9px] font-black text-slate-400 uppercase tracking-widest">Étudiant</th>
                  <th className="px-6 py-4 text-left text-[9px] font-black text-slate-400 uppercase tracking-widest">Badges</th>
                  <th className="px-6 py-4 text-right text-[9px] font-black text-slate-400 uppercase tracking-widest">Points</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-50">
                {topUsers.map((u, index) => {
                  const { stats, badges } = getRankStats(u, index);
                  const isTop3 = index < 3;
                  const isUser = u.uid === profile.uid;
                  
                  return (
                    <motion.tr 
                      key={u.uid}
                      initial={{ opacity: 0, y: 10 }}
                      animate={{ opacity: 1, y: 0 }}
                      transition={{ delay: index * 0.05 }}
                      onClick={() => onViewProfile(u)}
                      className={cn(
                        "group hover:bg-slate-50 cursor-pointer transition-colors",
                        isUser && "bg-indigo-50/30"
                      )}
                    >
                      <td className="px-6 py-5">
                         <div className="flex items-center gap-3">
                            {index === 0 ? (
                               <div className="w-8 h-8 rounded-full bg-amber-100 flex items-center justify-center text-amber-600 shadow-sm group-hover:scale-110 transition-transform">
                                  <Crown size={16} strokeWidth={3} />
                               </div>
                            ) : index === 1 ? (
                               <div className="w-8 h-8 rounded-full bg-slate-200 flex items-center justify-center text-slate-600 shadow-sm">
                                  <Medal size={16} />
                               </div>
                            ) : index === 2 ? (
                               <div className="w-8 h-8 rounded-full bg-orange-100 flex items-center justify-center text-orange-600 shadow-sm">
                                  <Medal size={16} />
                               </div>
                            ) : (
                               <span className="text-sm font-black text-slate-400 w-8 text-center">#{index + 1}</span>
                            )}
                         </div>
                      </td>
                      <td className="px-6 py-5">
                         <div className="flex items-center gap-4">
                            <div className="relative shrink-0">
                               <img src={u.photoUrl || "https://ui-avatars.com/api/?name="+u.firstName} alt="" className="w-10 h-10 rounded-2xl object-cover border-2 border-white shadow-md group-hover:rotate-3 transition-transform" />
                               {u.isBureauMember && (
                                 <div className="absolute -bottom-1 -right-1 bg-rose-500 text-white p-1 rounded-lg border-2 border-white shadow-sm">
                                    <ShieldCheck size={10} />
                                 </div>
                               )}
                            </div>
                            <div className="min-w-0">
                               <div className="flex items-center gap-2">
                                  <h4 className={cn("text-sm font-black tracking-tight", isUser ? "text-indigo-600" : "text-slate-800")}>
                                     {u.firstName} {u.lastName}
                                  </h4>
                               </div>
                               <p className="text-[9px] text-slate-400 font-bold uppercase tracking-wider">{u.department}</p>
                            </div>
                         </div>
                      </td>
                      <td className="px-6 py-5">
                         <div className="flex flex-wrap gap-2">
                            {badges.map((b, i) => (
                              <span key={i} className={cn("px-2 py-1 rounded-lg text-[8px] font-black uppercase tracking-wider flex items-center gap-1 shadow-sm", b.color)}>
                                 {b.icon}
                                 {b.label}
                              </span>
                            ))}
                            {badges.length === 0 && <span className="text-[10px] text-slate-300 font-bold italic">-</span>}
                         </div>
                      </td>
                      <td className="px-6 py-5 text-right">
                         <div className="flex flex-col items-end">
                            <span className="text-lg font-black text-slate-900 tracking-tighter">{stats.points.toLocaleString()}</span>
                            <div className="flex items-center gap-3 text-[8px] font-bold text-slate-400 uppercase tracking-widest mt-1">
                               <span className="flex items-center gap-1"><MessageCircle size={10} /> {stats.totalMessages}</span>
                               <span className="flex items-center gap-1"><User size={10} /> {stats.crossDeptInteractions?.length || 0}</span>
                            </div>
                         </div>
                      </td>
                    </motion.tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
