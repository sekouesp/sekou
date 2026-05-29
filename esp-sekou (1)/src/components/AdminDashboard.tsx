import { useState, useEffect } from "react";
import { UserProfile, AppConfig } from "../App";
import { db } from "../firebase";
import { collection, onSnapshot, doc, updateDoc, query, getDocs, addDoc, deleteDoc, Timestamp } from "firebase/firestore";
import { toast } from "sonner";
import { motion } from "motion/react";
import { 
  Users, 
  Settings, 
  BarChart3, 
  UserCheck, 
  Shield, 
  ToggleLeft, 
  ToggleRight,
  UserX,
  MessageCircle,
  Trophy,
  Music,
  Plus,
  Trash2,
  Globe,
  School,
  Play,
  Pause
} from "lucide-react";
import { cn } from "../lib/utils";
import { COMMISSIONS, DEPARTMENTS } from "../lib/theme";

interface AdminDashboardProps {
  profile: UserProfile;
  config: AppConfig;
}

export default function AdminDashboard({ profile, config }: AdminDashboardProps) {
  const [users, setUsers] = useState<UserProfile[]>([]);
  const [conversations, setConversations] = useState<any[]>([]);
  const [sounds, setSounds] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState<"stats" | "users" | "culturel">("stats");
  const [stats, setStats] = useState({
    totalPoints: 0,
    totalMessages: 0,
    ambassadors: 0,
    deptPoints: {} as Record<string, number>
  });

  // New sound form
  const [newSound, setNewSound] = useState({ name: "", url: "", type: "communal" as "communal" | "department", department: "" });
  const [deptLogos, setDeptLogos] = useState<Record<string, string>>(config.departmentLogos || {});
  const [communalLogo, setCommunalLogo] = useState(config.communalLogo || "");
  const [commissionLinks, setCommissionLinks] = useState<Record<string, string>>(config.commissionLinks || {});
  const [filterCommission, setFilterCommission] = useState<string>("all");
  const [filterDeureudj, setFilterDeureudj] = useState<string>("all");

  useEffect(() => {
    const unsubUsers = onSnapshot(collection(db, "users"), (snap) => {
      let userData = snap.docs.map(doc => ({ uid: doc.id, ...doc.data() } as UserProfile));
      if (profile.role !== 'super-admin') {
        userData = userData.filter(u => u.role !== 'super-admin');
      }
      setUsers(userData);
      
      let totalP = 0;
      let totalM = 0;
      let amb = 0;
      const deptP: Record<string, number> = {};

      userData.forEach(u => {
        const points = u.interactionStats?.points || 0;
        totalP += points;
        totalM += u.interactionStats?.totalMessages || 0;
        
        if (u.department) {
          deptP[u.department] = (deptP[u.department] || 0) + points;
        }

        if (u.interactionStats?.crossDeptInteractions && u.interactionStats.crossDeptInteractions.length >= 3) {
          amb++;
        }
      });

      setStats({
        totalPoints: totalP,
        totalMessages: totalM,
        ambassadors: amb,
        deptPoints: deptP
      });
      setLoading(false);
    });

    const unsubConvs = onSnapshot(collection(db, "conversations"), (snap) => {
      setConversations(snap.docs.map(doc => ({ id: doc.id, ...doc.data() })));
    });

    const unsubSounds = onSnapshot(collection(db, "culturel_sounds"), (snap) => {
      setSounds(snap.docs.map(doc => ({ id: doc.id, ...doc.data() })));
    });

    return () => {
      unsubUsers();
      unsubConvs();
      unsubSounds();
    };
  }, []);

  const [editingSound, setEditingSound] = useState<any>(null);
  const [lyricsText, setLyricsText] = useState("");

  const handleEditSound = (sound: any) => {
    setEditingSound(sound);
    setLyricsText((sound.lyrics || []).join("\n"));
  };

  const addSound = async () => {
    if (!newSound.name || !newSound.url) return;
    await addDoc(collection(db, "culturel_sounds"), {
      ...newSound,
      lyrics: [],
      createdAt: Timestamp.now()
    });
    setNewSound({ name: "", url: "", type: "communal", department: "" });
  };

  const deleteSound = async (id: string) => {
    await deleteDoc(doc(db, "culturel_sounds", id));
    if (editingSound?.id === id) setEditingSound(null);
  };

  const saveLyricsText = async () => {
    if (!editingSound) return;
    const lines = lyricsText.split("\n").map(l => l.trim()).filter(l => l.length > 0);
    await updateDoc(doc(db, "culturel_sounds", editingSound.id), {
      lyrics: lines
    });
    setEditingSound({ ...editingSound, lyrics: lines });
    toast.success("Paroles enregistrées !");
  };

  const saveLogos = async () => {
    await updateDoc(doc(db, "config", "global"), {
      departmentLogos: deptLogos,
      communalLogo: communalLogo
    });
    toast.success("Logos enregistrés avec succès");
  };

  const saveCommissionLinks = async () => {
    await updateDoc(doc(db, "config", "global"), {
      commissionLinks: commissionLinks
    });
    toast.success("Liens commissions enregistrés avec succès");
  };

  const toggleConfig = async (key: keyof AppConfig) => {
    await updateDoc(doc(db, "config", "global"), {
      [key]: !config[key]
    });
  };

  const promoteUser = async (user: UserProfile) => {
    const newRole = user.role === 'user' ? 'admin' : 'user';
    await updateDoc(doc(db, "users", user.uid), {
      role: newRole,
      isBureauMember: newRole === 'admin',
      bureauRole: newRole === 'admin' ? "Membre" : ""
    });
  };

  const updateBureauRole = async (user: UserProfile, bureauRole: string) => {
    await updateDoc(doc(db, "users", user.uid), {
      bureauRole,
      isBureauMember: true
    });
  };

  const toggleJoker = async (user: UserProfile) => {
    const isJoker = user.bureauRole === "Joker";
    await updateDoc(doc(db, "users", user.uid), {
      role: isJoker ? "user" : "admin",
      bureauRole: isJoker ? "" : "Joker",
      isBureauMember: !isJoker
    });
  };

  const toggleLock = async (user: UserProfile) => {
    await updateDoc(doc(db, "users", user.uid), {
      isLocked: !user.isLocked
    });
  };

  const getContactedCount = () => {
    const contactedIds = new Set();
    conversations.forEach(c => {
      // Find the regular user(s) in this conversation
      c.participantIds.forEach((id: string) => {
        const u = users.find(user => user.uid === id);
        if (u && u.role === 'user' && !u.isBureauMember) {
          contactedIds.add(id);
        }
      });
    });
    return contactedIds.size;
  };

  const regularUsers = users.filter(u => u.role === 'user' && !u.isBureauMember);
  const bureauUsers = users.filter(u => u.isBureauMember);
  const contactedCount = getContactedCount();
  const contactProgress = regularUsers.length > 0 ? (contactedCount / regularUsers.length) * 100 : 0;

  return (
    <div className="space-y-10 pb-20">
      <header className="flex flex-col md:flex-row md:items-center justify-between gap-6 px-2">
        <div>
          <h1 className="text-3xl font-bold text-slate-800 tracking-tight">Console de Gestion</h1>
          <p className="text-slate-400 text-sm font-medium mt-1 uppercase tracking-widest">Intégration & Unité Promotionnelle</p>
        </div>
        <div className="flex bg-slate-100 p-1 rounded-2xl border border-slate-200">
           <button 
            onClick={() => setActiveTab("stats")}
            className={cn("px-4 py-2 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all", activeTab === "stats" ? "bg-white text-slate-900 shadow-sm" : "text-slate-500 hover:text-slate-700")}
           >
             Stats
           </button>
           <button 
            onClick={() => setActiveTab("users")}
            className={cn("px-4 py-2 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all", activeTab === "users" ? "bg-white text-slate-900 shadow-sm" : "text-slate-500 hover:text-slate-700")}
           >
             Membres
           </button>
           <button 
            onClick={() => setActiveTab("culturel")}
            className={cn("px-4 py-2 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all", activeTab === "culturel" ? "bg-white text-slate-900 shadow-sm" : "text-slate-500 hover:text-slate-700")}
           >
             Culturel
           </button>
        </div>
      </header>

      {activeTab === "stats" && (
        <>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {[
          { label: "Membres Totaux", value: users.length, icon: Users, color: "bg-blue-600" },
          { label: "Total Points", value: stats.totalPoints.toLocaleString(), icon: Trophy, color: "bg-amber-600" },
          { label: "Membres Bureau", value: bureauUsers.length, icon: Shield, color: "bg-slate-800" },
          { label: "DUT 1 Contactés", value: `${contactedCount} / ${regularUsers.length}`, icon: UserCheck, color: "bg-emerald-600" },
        ].map((stat, i) => (
          <motion.div 
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: i * 0.1 }}
            key={i} 
            className="group relative overflow-hidden bg-white p-6 rounded-2xl border border-slate-200 shadow-sm hover:shadow-md transition-shadow"
          >
            <div className={cn("absolute -right-4 -top-4 w-16 h-16 opacity-5 group-hover:scale-150 transition-transform rounded-full", stat.color)}></div>
            <div className={cn("relative z-10 w-10 h-10 rounded-xl flex items-center justify-center text-white mb-4 shadow-sm", stat.color)}>
              <stat.icon size={20} />
            </div>
            <p className="relative z-10 text-[10px] font-bold text-slate-400 uppercase tracking-widest">{stat.label}</p>
            <h3 className="relative z-10 text-2xl font-bold text-slate-800 mt-1">{stat.value}</h3>
          </motion.div>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
           {/* Progress Card */}
           <div className="lg:col-span-2 bg-white rounded-3xl p-8 border border-slate-200 shadow-sm flex flex-col">
          <div className="flex items-center justify-between mb-8">
             <div>
                <h3 className="text-lg font-bold text-slate-800 uppercase tracking-tight">Statistiques de Couverture</h3>
                <p className="text-xs text-slate-400 font-medium">Analyse des interactions Bureau vs DUT 1</p>
             </div>
             <BarChart3 size={20} className="text-blue-600" />
          </div>
          
          <div className="space-y-8 grow justify-center">
            <div className="relative h-4 w-full bg-slate-100 rounded-full overflow-hidden">
               <motion.div 
                initial={{ width: 0 }}
                animate={{ width: `${contactProgress}%` }}
                className="absolute inset-y-0 left-0 bg-blue-600 rounded-full shadow-lg shadow-blue-500/20"
               />
            </div>
            <div className="flex justify-between items-baseline">
               <div className="flex items-baseline gap-2">
                  <span className="text-3xl font-bold text-slate-800">{Math.round(contactProgress)}%</span>
                  <span className="text-xs font-bold text-slate-400 uppercase tracking-widest">Couverture</span>
               </div>
               <div className="flex flex-col items-end gap-1">
                  <span className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">{regularUsers.length - contactedCount} Restant</span>
                  <div className="flex gap-4">
                    <div className="text-right">
                       <p className="text-[8px] font-bold text-slate-400 uppercase">Messages</p>
                       <p className="text-xs font-black text-slate-800">{stats.totalMessages.toLocaleString()}</p>
                    </div>
                    <div className="text-right">
                       <p className="text-[8px] font-bold text-slate-400 uppercase">Ambassadeurs</p>
                       <p className="text-xs font-black text-rose-600">{stats.ambassadors}</p>
                    </div>
                  </div>
               </div>
            </div>

            {/* Department Breakdown */}
            <div className="pt-8 border-t border-slate-100">
               <h4 className="text-[10px] font-bold text-slate-400 uppercase tracking-[0.2em] mb-4">Points par Département</h4>
               <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
                  {Object.entries(stats.deptPoints).sort((a,b) => b[1]-a[1]).map(([dept, pts]) => (
                    <div key={dept} className="p-3 bg-slate-50 rounded-xl border border-slate-100 flex flex-col items-center text-center">
                       <span className="text-[8px] font-black uppercase text-slate-400 mb-1">{dept}</span>
                       <span className="text-sm font-black text-slate-800">{pts.toLocaleString()}</span>
                    </div>
                  ))}
               </div>
            </div>

            {/* Incomplete list */}
            <div className="pt-8 border-t border-slate-100">
               <h4 className="text-[10px] font-bold text-slate-400 uppercase tracking-[0.2em] mb-6">À Contacter Prioritairement</h4>
               <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  {regularUsers.filter(u => {
                    const hasConv = conversations.some(c => c.participantIds.includes(u.uid));
                    return !hasConv;
                  }).slice(0, 4).map(u => (
                    <div key={u.uid} className="flex items-center gap-3 p-3 bg-slate-50 rounded-2xl border border-slate-200 group hover:bg-white hover:shadow-md transition-all">
                       <img src={u.photoUrl} alt="" className="w-10 h-10 rounded-full grayscale group-hover:grayscale-0 transition-all border border-white shadow-sm" />
                       <div className="flex flex-col truncate">
                          <span className="text-xs font-bold truncate text-slate-700">{u.firstName} {u.lastName}</span>
                          <span className="text-[10px] text-slate-400 font-medium truncate uppercase tracking-tighter">{u.department}</span>
                       </div>
                    </div>
                  ))}
               </div>
            </div>
          </div>
        </div>

        {/* Controls Card */}
        <div className="bg-[#0F172A] text-white rounded-3xl p-8 shadow-xl flex flex-col">
          <div className="flex items-center gap-3 mb-10">
             <div className="bg-blue-600 p-2 rounded-lg text-white">
                <Settings size={18} />
             </div>
             <h3 className="text-lg font-bold uppercase tracking-tight">Console de Contrôle</h3>
          </div>

          <div className="space-y-4 flex-1">
            {[
              { id: "inscriptionOnly", label: "Mode Inscription", desc: "Verrouille les discussions." },
              { id: "disableChat", label: "Désactiver Discussion", desc: "Coupe tout accès au chat." },
              { id: "rankingEnabled", label: "Activer Classement", desc: "Affiche le top des étudiants." },
              { id: "culturelEnabled", label: "Activer Culturel", desc: "Affiche l'onglet Culturel." },
              { id: "annoncesEnabled", label: "Activer Annonces", desc: "Affiche l'onglet Annonces." },
              { id: "parrotMuseumEnabled", label: "Musée Perroquet", desc: "Affiche la galerie des perroquets." },
              { id: "showValues", label: "Afficher les Valeurs", desc: "Axe de conduite promo." },
              { id: "showOath", label: "Afficher le Serment", desc: "Rituel d'intégration." },
            ].map((item) => (
              <div key={item.id} className="flex items-center justify-between gap-4 p-4 rounded-2xl bg-white/5 border border-white/5 hover:bg-white/10 transition-colors">
                <div>
                  <p className="text-xs font-bold uppercase tracking-wide">{item.label}</p>
                  <p className="text-[10px] text-slate-400 mt-1 italic">{item.desc}</p>
                </div>
                <button 
                  onClick={() => toggleConfig(item.id as keyof AppConfig)}
                  className="p-1 focus:outline-none"
                >
                  {config[item.id as keyof AppConfig] ? (
                    <ToggleRight size={28} className="text-blue-500" />
                  ) : (
                    <ToggleLeft size={28} className="text-slate-700" />
                  )}
                </button>
              </div>
            ))}
          </div>

          <div className="mt-10 p-5 bg-blue-600/10 rounded-2xl border border-blue-500/20">
             <p className="text-[10px] uppercase font-bold tracking-[0.2em] text-blue-400 mb-2">Note IT Commission</p>
             <p className="text-xs text-slate-300 leading-relaxed italic border-b border-blue-500/10 pb-4 mb-4">
               La fluidité des échanges est la clé de l'unité. Surveillez les statistiques de couverture quotidiennement.
             </p>
             
             {profile.role === 'super-admin' && (
               <div className="space-y-4">
                 <div className="flex items-center justify-between text-white/80">
                    <span className="text-[10px] uppercase font-bold tracking-widest">Limite Classement</span>
                    <input 
                      type="number" 
                      value={config.rankingLimit || 100} 
                      onChange={(e) => updateDoc(doc(db, "config", "global"), { rankingLimit: parseInt(e.target.value) || 100 })}
                      className="w-20 bg-white/5 border border-white/10 rounded-lg p-1.5 text-center font-bold text-xs"
                    />
                 </div>
               </div>
             )}
          </div>
        </div>
      </div>
      
      <section className="bg-white rounded-3xl p-8 border border-slate-200 shadow-sm mt-8">
        <div className="flex flex-col md:flex-row md:items-center justify-between mb-6 gap-4">
          <div>
            <h3 className="text-lg font-bold text-slate-800 uppercase tracking-tight">Liens WhatsApp Commissions</h3>
            <p className="text-xs text-slate-400 font-medium">Configurez les liens d'invitation pour chaque commission</p>
          </div>
          <button 
            onClick={saveCommissionLinks}
            className="bg-blue-600 text-white px-6 py-2 rounded-xl text-[10px] font-black uppercase tracking-widest hover:bg-blue-700 transition-all font-semibold"
          >
            Enregistrer Liens
          </button>
        </div>
        
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {[...COMMISSIONS, "Deureudj"].map(commission => (
            <div key={commission} className="space-y-2">
               <label className="text-[10px] font-bold text-slate-800 uppercase tracking-widest flex items-center gap-2">
                 <img src="https://res.cloudinary.com/dkpqkwjgo/image/upload/v1773944021/WhatsApp_qyvy28.svg" className="w-4 h-4" alt="WhatsApp" /> {commission}
               </label>
               <input 
                 type="text" 
                 value={commissionLinks[commission] || ""}
                 onChange={(e) => setCommissionLinks({...commissionLinks, [commission]: e.target.value})}
                 className="w-full bg-slate-50 border border-slate-200 rounded-xl p-3 text-sm focus:ring-2 focus:ring-emerald-500/20 outline-none"
                 placeholder="Follow this link to join my WhatsApp group: https://chat.whatsapp.com/..."
               />
            </div>
          ))}
        </div>
      </section>
      </>
      )}

      {activeTab === "culturel" && (
        <div className="space-y-8">
           {/* Logo Configuration */}
           <section className="bg-white rounded-3xl p-8 border border-slate-200 shadow-sm">
             <div className="flex items-center justify-between mb-8">
                <div>
                  <h3 className="text-lg font-bold text-slate-800 uppercase tracking-tight">Configuration des Logos</h3>
                  <p className="text-xs text-slate-400 font-medium">Logos par département et communal</p>
                </div>
                <button 
                  onClick={saveLogos}
                  className="bg-blue-600 text-white px-6 py-2 rounded-xl text-[10px] font-black uppercase tracking-widest hover:bg-blue-700 transition-all"
                >
                  Enregistrer Logos
                </button>
             </div>
             
             <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                <div className="space-y-2">
                   <label className="text-[10px] font-bold text-slate-400 uppercase tracking-widest flex items-center gap-2">
                     <Globe size={12} /> Logo Communal (URL)
                   </label>
                   <input 
                    type="text" 
                    value={communalLogo}
                    onChange={(e) => setCommunalLogo(e.target.value)}
                    className="w-full bg-slate-50 border border-slate-200 rounded-xl p-3 text-sm focus:ring-2 focus:ring-blue-500/20 outline-none"
                    placeholder="https://..."
                   />
                </div>
                {DEPARTMENTS.map(dept => (
                  <div key={dept} className="space-y-2">
                     <label className="text-[10px] font-bold text-slate-400 uppercase tracking-widest flex items-center gap-2">
                       <School size={12} /> {dept}
                     </label>
                     <input 
                      type="text" 
                      value={deptLogos[dept] || ""}
                      onChange={(e) => setDeptLogos({...deptLogos, [dept]: e.target.value})}
                      className="w-full bg-slate-50 border border-slate-200 rounded-xl p-3 text-sm focus:ring-2 focus:ring-blue-500/20 outline-none"
                      placeholder="URL de l'image"
                     />
                  </div>
                ))}
             </div>
           </section>

           {/* Add Sound Form */}
           <section className="bg-white rounded-3xl p-8 border border-slate-200 shadow-sm">
             <h3 className="text-lg font-bold text-slate-800 uppercase tracking-tight mb-8">Ajouter un Son</h3>
             <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 items-end">
                <div className="space-y-2">
                   <label className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Nom du Son</label>
                   <input 
                    type="text" 
                    value={newSound.name}
                    onChange={(e) => setNewSound({...newSound, name: e.target.value})}
                    className="w-full bg-slate-50 border border-slate-200 rounded-xl p-3 text-sm focus:ring-2 focus:ring-blue-500/20 outline-none"
                    placeholder="Ex: Cri de guerre"
                   />
                </div>
                <div className="space-y-2">
                   <label className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Lien Audio (URL)</label>
                   <input 
                    type="text" 
                    value={newSound.url}
                    onChange={(e) => setNewSound({...newSound, url: e.target.value})}
                    className="w-full bg-slate-50 border border-slate-200 rounded-xl p-3 text-sm focus:ring-2 focus:ring-blue-500/20 outline-none"
                    placeholder="https://..."
                   />
                </div>
                <div className="space-y-2">
                   <label className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Type</label>
                   <select 
                    value={newSound.type}
                    onChange={(e) => setNewSound({...newSound, type: e.target.value as any})}
                    className="w-full bg-slate-50 border border-slate-200 rounded-xl p-3 text-sm focus:ring-2 focus:ring-blue-500/20 outline-none"
                   >
                     <option value="communal">Communal</option>
                     <option value="department">Départemental</option>
                   </select>
                </div>
                {newSound.type === 'department' ? (
                  <div className="space-y-2">
                    <label className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Département</label>
                    <select 
                      value={newSound.department}
                      onChange={(e) => setNewSound({...newSound, department: e.target.value})}
                      className="w-full bg-slate-50 border border-slate-200 rounded-xl p-3 text-sm focus:ring-2 focus:ring-blue-500/20 outline-none"
                    >
                      <option value="">Sélectionner</option>
                      {DEPARTMENTS.map(d => <option key={d} value={d}>{d}</option>)}
                    </select>
                  </div>
                ) : (
                  <div />
                )}
             </div>
             <button 
                onClick={addSound}
                disabled={!newSound.name || !newSound.url || (newSound.type === 'department' && !newSound.department)}
                className="mt-6 w-full bg-slate-900 text-white py-4 rounded-2xl flex items-center justify-center gap-2 text-[10px] font-black uppercase tracking-widest hover:bg-slate-800 transition-all shadow-lg active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                <Plus size={16} /> Ajouter le Son au Répertoire Culturel
              </button>
           </section>

           {/* Sound List */}
           {!editingSound ? (
             <section className="bg-white rounded-3xl p-8 border border-slate-200 shadow-sm overflow-hidden">
               <h3 className="text-lg font-bold text-slate-800 uppercase tracking-tight mb-8">Sons Enregistrés</h3>
               <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                  {sounds.map(sound => (
                    <div key={sound.id} onClick={() => setEditingSound(sound)} className="flex items-center justify-between p-4 bg-slate-50 rounded-2xl border border-slate-200 group cursor-pointer hover:border-blue-300">
                      <div className="flex items-center gap-4">
                        <div className="w-12 h-12 rounded-xl bg-white flex items-center justify-center border border-slate-200 shadow-sm overflow-hidden p-1">
                           {sound.type === 'communal' ? (
                             <img src={communalLogo || "https://res.cloudinary.com/dkpqkwjgo/image/upload/v1779016358/esp_sekou_logo_nobg_yh1xt7.png"} alt="" className="w-full h-full object-contain" />
                           ) : (
                             <img src={deptLogos[sound.department] || "https://res.cloudinary.com/dkpqkwjgo/image/upload/v1779016358/esp_sekou_logo_nobg_yh1xt7.png"} alt="" className="w-full h-full object-contain" />
                           )}
                        </div>
                        <div className="min-w-0">
                          <p className="text-xs font-bold text-slate-800 truncate">{sound.name}</p>
                          <p className="text-[8px] font-black text-slate-400 uppercase tracking-widest truncate">{sound.department || "Communal"}</p>
                        </div>
                      </div>
                      <button 
                        onClick={(e) => { e.stopPropagation(); deleteSound(sound.id); }}
                        className="p-2 text-slate-300 hover:text-rose-600 hover:bg-rose-50 rounded-lg transition-all active:scale-90"
                      >
                        <Trash2 size={16} />
                      </button>
                    </div>
                  ))}
               </div>
             </section>
           ) : (
             <section className="bg-white rounded-3xl p-8 border border-slate-200 shadow-sm overflow-hidden">
               <div className="flex items-center justify-between mb-8">
                 <div>
                   <h3 className="text-lg font-bold text-slate-800 uppercase tracking-tight flex items-center gap-2">
                     <button onClick={() => setEditingSound(null)} className="text-slate-400 hover:text-slate-800 transition-colors">
                       ←
                     </button>
                     Paroles: {editingSound.name}
                   </h3>
                   <p className="text-xs text-slate-400 font-medium">Ajoutez les paroles (une ligne par phrase)</p>
                 </div>
               </div>
               
               <div className="flex flex-col gap-4 mb-4">
                 <textarea 
                   value={lyricsText}
                   onChange={(e) => setLyricsText(e.target.value)}
                   className="w-full bg-slate-50 border border-slate-200 rounded-2xl p-6 min-h-[300px] text-sm focus:ring-2 focus:ring-blue-500/20 outline-none resize-y"
                   placeholder="Ligne 1 de la chanson&#10;Ligne 2 de la chanson&#10;..."
                 />
                 
                 <div className="flex justify-end">
                   <button 
                     onClick={saveLyricsText}
                     className="bg-blue-600 text-white px-6 py-3 rounded-xl hover:bg-blue-700 transition-all shadow-lg active:scale-95 text-sm font-bold flex items-center gap-2"
                   >
                     Enregistrer les paroles
                   </button>
                 </div>
               </div>
             </section>
           )}
        </div>
      )}

      {activeTab === "users" && (
        <section className="bg-white rounded-3xl p-8 border border-slate-200 shadow-sm overflow-hidden">
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-8">
          <h3 className="text-lg font-bold text-slate-800 uppercase tracking-tight">Gestion des Membres</h3>
          
          <div className="flex flex-col sm:flex-row gap-4">
             <select 
               value={filterCommission}
               onChange={(e) => setFilterCommission(e.target.value)}
               className="bg-slate-50 border border-slate-200 rounded-xl px-4 py-2 text-sm font-medium text-slate-700 outline-none focus:ring-2 focus:ring-blue-500/20"
             >
               <option value="all">Toutes Commissions</option>
               {COMMISSIONS.map(c => <option key={c} value={c}>{c}</option>)}
             </select>
             
             <select 
               value={filterDeureudj}
               onChange={(e) => setFilterDeureudj(e.target.value)}
               className="bg-slate-50 border border-slate-200 rounded-xl px-4 py-2 text-sm font-medium text-slate-700 outline-none focus:ring-2 focus:ring-blue-500/20"
             >
               <option value="all">Filtre Deureudj (Tous)</option>
               <option value="yes">Deureudj: Oui</option>
               <option value="no">Deureudj: Non</option>
             </select>
          </div>
        </div>
        <div className="overflow-x-auto -mx-8 px-8">
          <table className="w-full text-left">
            <thead>
              <tr className="text-[10px] uppercase tracking-[0.2em] text-slate-400 border-b border-slate-100">
                <th className="pb-4 font-bold">Profil Étudiant</th>
                <th className="pb-4 font-bold">Spécialité / Dept</th>
                <th className="pb-4 font-bold">Rang Système</th>
                <th className="pb-4 font-bold text-right">Action Directe</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-50">
              {users.filter(u => {
                let matchComm = true;
                if (filterCommission !== "all") {
                  matchComm = !!(u.commissions && u.commissions.includes(filterCommission));
                }
                
                let matchDeu = true;
                if (filterDeureudj === "yes") {
                   matchDeu = !!(u.commissions && u.commissions.includes("Deureudj"));
                } else if (filterDeureudj === "no") {
                   matchDeu = !u.commissions || !u.commissions.includes("Deureudj");
                }
                return matchComm && matchDeu;
              }).map(u => (
                <tr key={u.uid} className="group hover:bg-slate-50 transition-colors">
                  <td className="py-5">
                    <div className="flex items-center gap-3">
                      <img src={u.photoUrl} alt="" className="w-9 h-9 rounded-full object-cover border border-slate-100 shadow-sm" />
                      <div>
                        <p className="text-sm font-bold text-slate-800">{u.firstName} {u.lastName}</p>
                        <p className="text-[10px] text-slate-400 font-medium uppercase tracking-tighter">Membre Promotion 2026</p>
                      </div>
                    </div>
                  </td>
                  <td className="py-5">
                     <span className="text-xs font-bold text-slate-600 bg-slate-100 px-3 py-1 rounded-full uppercase tracking-tighter">
                        {u.department}
                     </span>
                  </td>
                  <td className="py-5">
                    <div className="flex flex-col gap-1">
                      <span className={cn(
                        "px-2.5 py-1 rounded text-[9px] font-bold uppercase tracking-widest w-fit",
                        u.role === 'super-admin' ? "bg-amber-100 text-amber-700 ring-1 ring-amber-200" : 
                        u.role === 'admin' ? "bg-blue-100 text-blue-700 ring-1 ring-blue-200" : "bg-slate-100 text-slate-500"
                      )}>
                        {u.role}
                      </span>
                      {u.bureauRole && (
                        <span className="text-[8px] font-black text-rose-600 uppercase tracking-widest">{u.bureauRole}</span>
                      )}
                    </div>
                  </td>
                  <td className="py-5 text-right">
                    <div className="flex items-center justify-end gap-3">
                       {/* Bureau Role Select */}
                       {u.isBureauMember && u.role !== 'super-admin' && (
                         <select 
                           value={u.bureauRole || "Membre"}
                           onChange={(e) => updateBureauRole(u, e.target.value)}
                           className="text-[9px] font-bold uppercase p-2 rounded-lg bg-slate-100 border-none outline-none focus:ring-2 focus:ring-blue-500/20"
                         >
                            <option value="Membre">Membre</option>
                            <option value="Président">Président</option>
                            <option value="Vice-Président">Vice-Président</option>
                            <option value="Joker">Joker</option>
                         </select>
                       )}

                       {u.uid !== profile.uid && (
                        <button 
                          onClick={() => toggleLock(u)}
                          className={cn(
                            "p-2 rounded-xl transition-all shadow-sm active:scale-95 border",
                            u.isLocked ? "bg-rose-50 text-rose-600 border-rose-100" : "bg-slate-50 text-slate-400 border-slate-200 hover:text-rose-500 hover:border-rose-200"
                          )}
                          title={u.isLocked ? "Déverrouiller" : "Verrouiller le compte"}
                        >
                          {u.isLocked ? <ToggleRight size={20} /> : <ToggleLeft size={20} />}
                        </button>
                       )}
                       
                       {profile.role === 'super-admin' && u.uid !== profile.uid && (
                        <div className="flex items-center gap-1">
                          <button 
                            onClick={() => toggleJoker(u)}
                            className={cn(
                              "text-[9px] font-bold uppercase tracking-[0.1em] px-3 py-2 rounded-lg transition-all shadow-sm active:scale-95 border",
                              u.bureauRole === "Joker" ? "bg-amber-500 text-white border-amber-600" : "bg-white text-slate-400 border-slate-200"
                            )}
                          >
                            Joker
                          </button>
                          <button 
                            onClick={() => promoteUser(u)}
                            className="text-[9px] font-bold uppercase tracking-[0.1em] px-3 py-2 bg-white text-slate-600 border border-slate-200 rounded-lg hover:border-blue-600 hover:text-blue-600 transition-all shadow-sm active:scale-95"
                          >
                            {u.role === 'admin' ? "Rétrograder" : "Promouvoir"}
                          </button>
                        </div>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
      )}
    </div>
  );
}
