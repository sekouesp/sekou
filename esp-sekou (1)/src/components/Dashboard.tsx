import { UserProfile, AppConfig } from "../App";
import { useEffect, useState } from "react";
import { db } from "../firebase";
import { collection, onSnapshot, query, orderBy } from "firebase/firestore";
import { motion, AnimatePresence } from "motion/react";
import { Search, MapPin, Sparkles, Filter, ShieldCheck } from "lucide-react";
import WhatsAppAnimatedButton from "./WhatsAppAnimatedButton";
import { cn } from "../lib/utils";
import UserDetailModal from "./UserDetailModal";

import { getDeptTheme } from "../lib/theme";

interface DashboardProps {
  profile: UserProfile;
  config: AppConfig;
  setActiveTab: (tab: string) => void;
  setChatTarget: (user: UserProfile) => void;
  onViewProfile?: (user: UserProfile) => void;
}

export default function Dashboard({ profile, config, setActiveTab, setChatTarget, onViewProfile }: DashboardProps) {
  const [users, setUsers] = useState<UserProfile[]>([]);
  const [searchTerm, setSearchTerm] = useState("");
  const [filterDept, setFilterDept] = useState("");
  const [loading, setLoading] = useState(true);
  const [selectedUser, setSelectedUser] = useState<UserProfile | null>(null);
  const theme = getDeptTheme(profile.department);

  useEffect(() => {
    const q = query(collection(db, "users"), orderBy("firstName", "asc"));
    const unsub = onSnapshot(q, (snap) => {
      const u = snap.docs.map(doc => ({ uid: doc.id, ...doc.data() } as UserProfile));
      setUsers(u);
      setLoading(false);
    });
    return unsub;
  }, []);

  const handleUserClick = (u: UserProfile) => {
    if (u.isBureauMember) {
      setSelectedUser(u);
    } else {
      onViewProfile?.(u);
    }
  };

  const filteredUsers = users.filter(u => {
    const matchesSearch = (u.firstName + " " + u.lastName).toLowerCase().includes(searchTerm.toLowerCase());
    const matchesDept = filterDept === "" || u.department === filterDept;
    return matchesSearch && matchesDept;
  });

  const departments = Array.from(new Set(users.map(u => u.department))).filter(Boolean);

  const handleStartChat = (user: UserProfile) => {
    setChatTarget(user);
    setActiveTab("chat");
    setSelectedUser(null);
  };

  return (
    <div className="space-y-6 md:space-y-10">
      <AnimatePresence>
        {selectedUser && (
          <UserDetailModal 
            user={selectedUser} 
            onClose={() => setSelectedUser(null)} 
            onStartChat={handleStartChat}
            onViewFullProfile={(u) => {
              setSelectedUser(null);
              onViewProfile?.(u);
            }}
          />
        )}
      </AnimatePresence>
      {/* Welcome & Stats Section */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className={cn("lg:col-span-2 rounded-3xl border p-8 md:p-10 flex flex-col md:flex-row items-center justify-between relative overflow-hidden shadow-sm transition-colors", theme.light, "border-"+theme.primary+"-100/50", "bg-gradient-to-br "+theme.light+" to-white")}>
          <div className="relative z-10 space-y-4 text-center md:text-left">
            <h2 className="text-3xl md:text-5xl font-black font-serif uppercase tracking-tighter text-slate-900 leading-[1.1]">
              "DUT 1 EST-CE QUE KHAMANTE NAGN SUNU BIRR ?"
            </h2>
            <p className="text-slate-600 text-sm md:text-base font-medium leading-relaxed">
              Bienvenue, {profile.firstName}.
            </p>

            {/* User Commissions Links */}
            {profile.commissions && profile.commissions.length > 0 && (
              <div className="flex flex-wrap items-center justify-center md:justify-start gap-3 pt-6 relative z-20">
                {profile.commissions.map(comm => {
                  let linkText = config.commissionLinks?.[comm] || "Follow this link to join my WhatsApp group: https://chat.whatsapp.com/IgyxVXKWYj3EQdHAZrD9dH";
                  
                  // Extract URL from standard WhatsApp share message
                  const urlMatch = linkText.match(/https:\/\/chat\.whatsapp\.com\/[A-Za-z0-9]+/);
                  const hrefParams = urlMatch ? urlMatch[0] : linkText;
                  
                  return (
                    <WhatsAppAnimatedButton 
                      key={comm}
                      commission={comm}
                      href={hrefParams}
                    />
                  );
                })}
              </div>
            )}
          </div>
          <div className="absolute -right-16 -bottom-16 opacity-[0.08] pointer-events-none hidden md:block">
            <img src="https://res.cloudinary.com/dkpqkwjgo/image/upload/v1779016358/esp_sekou_logo_nobg_yh1xt7.png" alt="" className="w-64 h-64 rotate-12" />
          </div>
        </div>

        {/* Personal Impact Card */}
        <div className="bg-slate-900 rounded-[2.5rem] p-8 text-white relative overflow-hidden shadow-2xl flex flex-col justify-between">
           <div className="relative z-10">
              <div className="flex items-center justify-between mb-6">
                 <h3 className="text-[10px] font-black uppercase tracking-[0.3em] text-slate-500">Ton Impact</h3>
                 <Sparkles size={16} className="text-amber-400" />
              </div>
              <div className="space-y-4">
                 <div className="flex justify-between items-end">
                    <div>
                       <p className="text-[8px] font-bold text-slate-500 uppercase mb-1">Points Accumulés</p>
                       <p className="text-3xl font-black tracking-tighter">{profile.interactionStats?.points || 0}</p>
                    </div>
                    <div className="text-right">
                       <p className="text-[8px] font-bold text-slate-500 uppercase mb-1">Classement</p>
                       <p className="text-xl font-black text-indigo-400">#{users.sort((a,b) => (b.interactionStats?.points || 0) - (a.interactionStats?.points || 0)).findIndex(u => u.uid === profile.uid) + 1 || "-"}</p>
                    </div>
                 </div>
                 
                 <div className="grid grid-cols-2 gap-3 pt-2">
                    <div className="bg-white/5 p-3 rounded-2xl border border-white/5 text-center">
                       <p className="text-[7px] font-bold text-slate-500 uppercase mb-1">Messages</p>
                       <p className="text-sm font-bold">{profile.interactionStats?.totalMessages || 0}</p>
                    </div>
                    <div className="bg-white/5 p-3 rounded-2xl border border-white/5 text-center">
                       <p className="text-[7px] font-bold text-slate-500 uppercase mb-1">Contacts</p>
                       <p className="text-sm font-bold">{profile.interactionStats?.startedConversations || 0}</p>
                    </div>
                 </div>
              </div>
           </div>
           <button 
             onClick={() => setActiveTab("ranking")}
             className="relative z-10 mt-6 w-full py-3 bg-white text-slate-900 rounded-2xl text-[10px] font-black uppercase tracking-widest hover:scale-[1.02] transition-transform active:scale-95"
             style={{ color: "#000000" }}
           >
             Voir le Classement
           </button>
        </div>
      </div>

      {/* Directory Section */}
      <section className="space-y-4 md:space-y-6">
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 px-1">
          <div className="space-y-1">
            <h2 className="text-lg md:text-xl font-bold text-slate-800 uppercase tracking-tight">
              Annuaire
            </h2>
            <p className="text-[10px] md:text-xs text-slate-400 font-medium tracking-wide">Découvrez vos camarades de promotion</p>
          </div>

          <div className="flex flex-col sm:flex-row items-center gap-2">
            <div className="relative group w-full sm:w-auto">
              <Search size={14} className={cn("absolute left-4 top-1/2 -translate-y-1/2 text-slate-400 transition-colors", "group-focus-within:" + theme.text)} />
              <input 
                type="text" 
                placeholder="Chercher..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className={cn("pl-11 pr-4 py-2 bg-white border border-slate-200 rounded-xl outline-none focus:ring-2 w-full sm:w-56 transition-all text-xs font-medium", theme.ring)}
              />
            </div>
            
            <div className="flex items-center gap-1 bg-white border border-slate-200 p-0.5 rounded-xl w-full sm:w-auto">
               <div className="p-2 text-slate-400">
                  <Filter size={14} />
               </div>
               <select 
                 value={filterDept}
                 onChange={(e) => setFilterDept(e.target.value)}
                 className="bg-transparent pr-4 py-1.5 outline-none text-[10px] font-bold text-slate-600 uppercase tracking-tighter cursor-pointer grow sm:grow-0"
               >
                 <option value="">Filtre Section</option>
                 {departments.map(d => <option key={d} value={d}>{d}</option>)}
               </select>
            </div>
          </div>
        </div>

        {loading ? (
          <div className="grid grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-3 md:gap-6">
             {[1,2,3,4,5,6].map(i => (
               <div key={i} className="h-48 md:h-64 bg-white rounded-2xl animate-pulse border border-slate-100 shadow-sm" />
             ))}
          </div>
        ) : (
          <div className="grid grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-3 md:gap-6">
            <AnimatePresence>
              {filteredUsers.map((u, idx) => (
                <motion.div
                  layout
                  initial={{ opacity: 0, scale: 0.95 }}
                  animate={{ opacity: 1, scale: 1 }}
                  transition={{ delay: idx * 0.02 }}
                  key={u.uid}
                  onClick={() => handleUserClick(u)}
                  className="bg-white/80 backdrop-blur-sm rounded-2xl p-4 md:p-6 shadow-sm hover:shadow-xl hover:-translate-y-1 transition-all group border border-slate-100 flex flex-col items-center text-center relative overflow-hidden cursor-pointer active:scale-[0.98]"
                >
                  <div className="mb-3 md:mb-4 relative">
                     <div className={cn("w-14 h-14 md:w-20 md:h-20 rounded-full p-1 border-2 border-slate-50 transition-colors bg-white", "group-hover:border-"+theme.primary+"-500")}>
                        <img 
                          src={u.photoUrl || "https://ui-avatars.com/api/?name=" + u.firstName + "+" + u.lastName} 
                          alt="" 
                          className="w-full h-full rounded-full object-cover shadow-inner"
                        />
                     </div>
                  </div>
                  
                  <div className="space-y-1 min-w-0 w-full">
                    <h3 className="text-sm md:text-lg font-bold text-slate-800 truncate">{u.firstName}</h3>
                    <div className="flex items-center justify-center gap-1 text-[8px] md:text-[9px] text-slate-400 font-bold uppercase tracking-widest">
                      <span className="truncate">{u.department}</span>
                    </div>
                  </div>

                  <p className="mt-3 text-[10px] md:text-xs text-slate-500 line-clamp-2 md:line-clamp-3 leading-relaxed font-medium italic grow">
                    {u.bio ? u.bio : "ESPRIT ESP."}
                  </p>

                  <div className="mt-4 pt-3 border-t border-slate-50 w-full flex flex-col items-center gap-2 opacity-60 group-hover:opacity-100 transition-opacity">
                    {(config.rankingEnabled || profile.role !== 'user') ? (
                      <span className={cn("text-[8px] px-2 py-0.5 rounded font-bold uppercase", theme.light, theme.text)}>
                        {u.interactionStats?.points || 0} pts
                      </span>
                    ) : (
                      <span className={cn("text-[8px] px-2 py-0.5 rounded font-bold uppercase", theme.light, theme.text)}>
                        Polytechnicien
                      </span>
                    )}
                    {u.commissions && u.commissions.length > 0 && (
                      <span className="text-[7px] font-black uppercase text-slate-400 tracking-tighter">
                        +{u.commissions.length} {u.commissions.length === 1 ? 'Commission' : 'Commissions'}
                      </span>
                    )}
                  </div>
                </motion.div>
              ))}
            </AnimatePresence>
          </div>
        )}
      </section>
    </div>
  );
}
