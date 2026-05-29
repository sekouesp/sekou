import { useEffect, useState } from "react";
import { Toaster, toast } from "sonner";
import { collection, query, orderBy, limit, onSnapshot, where, Timestamp, doc, getDoc } from "firebase/firestore";
import { onAuthStateChanged, User as FirebaseUser } from "firebase/auth";
import { auth, db } from "./firebase";
import { Megaphone, MessageCircle } from "lucide-react";
import Landing from "./components/Landing";
import Auth from "./components/Auth";
import Layout from "./components/Layout";
import Dashboard from "./components/Dashboard";
import Chat from "./components/Chat";
import Notifications from "./components/Notifications";
import AdminDashboard from "./components/AdminDashboard";
import Profile from "./components/Profile";
import Values from "./components/Values";
import Oath from "./components/Oath";
import ParrotMuseum from "./components/ParrotMuseum";
import Ranking from "./components/Ranking";
import Culturel from "./components/Culturel";
import { Notification } from "./components/NotificationBell";
import PublicProfile from "./components/PublicProfile";

export type Role = "user" | "admin" | "super-admin";

export interface UserProfile {
  uid: string;
  firstName: string;
  lastName: string;
  photoUrl: string;
  department: string;
  bio: string;
  hobbies: string;
  role: Role;
  isBureauMember: boolean;
  bureauRole?: string;
  isLocked?: boolean;
  commissions?: string[];
  interactionStats?: {
    points: number;
    startedConversations: number;
    totalMessages: number;
    crossDeptInteractions: string[];
  };
  badges?: string[];
}

export interface AppConfig {
  inscriptionOnly: boolean;
  showValues: boolean;
  showOath: boolean;
  disableChat: boolean;
  rankingEnabled: boolean;
  parrotMuseumEnabled: boolean;
  rankingLimit: number;
  culturelEnabled: boolean;
  annoncesEnabled: boolean;
  departmentLogos?: Record<string, string>;
  communalLogo?: string;
  commissionLinks?: Record<string, string>;
}

const getDeptToastColor = (dept?: string) => {
  switch (dept) {
    case "Génie Informatique": return "text-indigo-600";
    case "Génie Civil": return "text-amber-600";
    case "Génie Électrique": return "text-cyan-600";
    case "Génie Mécanique": return "text-slate-700";
    case "Génie Chimique & Biologie": return "text-emerald-600";
    case "Gestion": return "text-rose-600";
    default: return "text-blue-600";
  }
};

export default function App() {
  const [user, setUser] = useState<FirebaseUser | null>(null);
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [config, setConfig] = useState<AppConfig>({
    inscriptionOnly: true,
    showValues: true,
    showOath: true,
    disableChat: false,
    rankingEnabled: true,
    parrotMuseumEnabled: false,
    rankingLimit: 100,
    culturelEnabled: true,
    annoncesEnabled: true
  });
  const [loading, setLoading] = useState(true);
  const [showLanding, setShowLanding] = useState(true);
  const [activeTab, setActiveTab] = useState("home");
  const [chatTarget, setChatTarget] = useState<UserProfile | null>(null);
  const [selectedUserProfile, setSelectedUserProfile] = useState<UserProfile | null>(null);
  const [notifications, setNotifications] = useState<Notification[]>([]);

  const deptColor = getDeptToastColor(profile?.department);

  // Notification Listener
  useEffect(() => {
    if (!user || !profile) return;

    // Listen for new broadcasts
    const lastCheck = Timestamp.now();
    const q = query(
      collection(db, "broadcasts"),
      where("createdAt", ">", lastCheck),
      orderBy("createdAt", "desc")
    );

    const unsub = onSnapshot(q, (snap) => {
      snap.docChanges().forEach((change) => {
        if (change.type === "added") {
          const data = change.doc.data();
          const id = change.doc.id;
          
          // Filter by department if applicable
          if (!data.filterDept || data.filterDept === profile.department) {
            // Toast
            toast("Annonce Bureau", {
              description: data.text,
              duration: 10000,
              icon: <Megaphone className={deptColor} size={18} />
            });

            // Add to notification list
            setNotifications(prev => {
              if (prev.find(n => n.id === id)) return prev;
              return [{
                id,
                type: "broadcast",
                title: "Annonce du Bureau",
                text: data.text,
                timestamp: data.createdAt || Timestamp.now(),
                read: false,
                targetTab: "notifications"
              }, ...prev];
            });
          }
        }
      });
    });

    return () => unsub();
  }, [user, profile, deptColor]);

  // Message Notification Listener
  useEffect(() => {
    if (!user || !profile || config.disableChat) return;

    const q = query(
      collection(db, "conversations"),
      where("participantIds", "array-contains", user.uid)
    );

    const unsub = onSnapshot(q, (snap) => {
      snap.docChanges().forEach((change) => {
        const data = change.doc.data();
        const convId = change.doc.id;

        if (change.type === "modified") {
          const lastMsg = data.lastMessageAt;
          const senderId = data.lastSenderId; // We need to store this in Chat.tsx
          const text = data.lastMessageText || "Nouveau message";

          if (senderId && senderId !== user.uid) {
            // Only notify if user is NOT on the chat tab looking at this conversation
            // This is hard to detect perfectly here, but we can check activeTab
            if (activeTab !== "chat") {
              toast("Nouveau Message", {
                description: text,
                icon: <MessageCircle className={deptColor} size={18} />,
                action: {
                  label: "Voir",
                  onClick: () => setActiveTab("chat")
                }
              });

              setNotifications(prev => {
                const id = `msg_${convId}_${lastMsg?.toMillis()}`;
                if (prev.find(n => n.id === id)) return prev;
                return [{
                  id,
                  type: "message",
                  title: "Nouveau message",
                  text,
                  timestamp: lastMsg || Timestamp.now(),
                  read: false,
                  targetTab: "chat"
                }, ...prev];
              });
            }
          }
        }
      });
    });

    return () => unsub();
  }, [user, profile, activeTab, config.disableChat, deptColor]);

  useEffect(() => {
    const unsubAuth = onAuthStateChanged(auth, async (u) => {
      setUser(u);
      if (u) {
        const snap = await getDoc(doc(db, "users", u.uid));
        if (snap.exists()) {
          setProfile({ uid: u.uid, ...snap.data() } as UserProfile);
        } else {
          setProfile(null);
        }
      } else {
        setProfile(null);
      }
      setLoading(false);
    });

    const unsubConfig = onSnapshot(doc(db, "config", "global"), (snap) => {
      if (snap.exists()) {
        setConfig(snap.data() as AppConfig);
      }
    });

    return () => {
      unsubAuth();
      unsubConfig();
    };
  }, []);

  const handleMarkAsRead = (id: string) => {
    setNotifications(prev => prev.map(n => n.id === id ? { ...n, read: !n.read } : n));
  };

  const handleMarkAllRead = () => {
    setNotifications(prev => prev.map(n => ({ ...n, read: true })));
  };

  const handleClearNotification = (id: string) => {
    setNotifications(prev => prev.filter(n => n.id !== id));
  };

  const handleOpenNotification = (n: Notification) => {
    setNotifications(prev => prev.map(notif => notif.id === n.id ? { ...notif, read: true } : notif));
    if (n.targetTab) setActiveTab(n.targetTab);
  };

  // Mark all broadcasts read when viewing notifications tab
  useEffect(() => {
    if (activeTab === "notifications") {
      setNotifications(prev => prev.map(n => n.type === "broadcast" ? { ...n, read: true } : n));
    }
    if (activeTab === "chat") {
       setNotifications(prev => prev.map(n => n.type === "message" ? { ...n, read: true } : n));
    }
  }, [activeTab]);

  if (showLanding) {
    return <Landing onComplete={() => setShowLanding(false)} />;
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen bg-[#f5f5f0]">
        <div className="animate-pulse">
           <img src="https://res.cloudinary.com/dkpqkwjgo/image/upload/v1779016358/esp_sekou_logo_nobg_yh1xt7.png" alt="ESP Sekou" className="w-24 h-24 mb-4" />
        </div>
      </div>
    );
  }

  if (!user) {
    return <Auth />;
  }

  if (!profile) {
    return <Profile mode="create" onComplete={(p) => setProfile(p)} />;
  }

  if (profile.isLocked) {
    return (
      <div className="min-h-screen bg-slate-950 flex items-center justify-center p-6 text-center">
        <div className="max-w-md w-full bg-white rounded-[40px] p-8 md:p-12 shadow-2xl border-4 border-rose-500/20">
          <div className="w-20 h-20 bg-rose-50 text-rose-600 rounded-2xl flex items-center justify-center mx-auto mb-8 shadow-lg shadow-rose-500/10 rotate-3">
             <Megaphone size={40} />
          </div>
          <h1 className="text-2xl md:text-3xl font-extrabold text-slate-900 tracking-tight mb-4 uppercase italic">Compte Verrouillé</h1>
          <p className="text-slate-500 text-sm font-medium leading-relaxed mb-8">
            Votre accès à la plateforme a été suspendu par le Bureau d'Intégration. Pour toute réclamation, veuillez contacter un membre du bureau.
          </p>
          <button 
            onClick={() => auth.signOut()}
            className="w-full bg-slate-900 text-white py-4 rounded-2xl font-bold hover:bg-slate-800 transition-all active:scale-95 shadow-xl"
          >
            Se déconnecter
          </button>
        </div>
      </div>
    );
  }

  return (
    <Layout 
      profile={profile} 
      config={config} 
      activeTab={activeTab} 
      setActiveTab={setActiveTab}
      notifications={notifications}
      onMarkAsRead={handleMarkAsRead}
      onMarkAllRead={handleMarkAllRead}
      onClear={handleClearNotification}
      onOpenNotification={handleOpenNotification}
    >
      <Toaster position="top-right" richColors />
      {activeTab === "home" && (
        <Dashboard 
          profile={profile} 
          config={config} 
          setActiveTab={setActiveTab} 
          setChatTarget={setChatTarget} 
          onViewProfile={(u) => {
            setSelectedUserProfile(u);
            setActiveTab("public-profile");
          }}
        />
      )}
      {activeTab === "public-profile" && selectedUserProfile && (
        <PublicProfile 
          user={selectedUserProfile} 
          viewerProfile={profile}
          config={config}
          onBack={() => setActiveTab("home")} 
          onMessage={(u) => {
            setChatTarget(u);
            setActiveTab("chat");
          }}
        />
      )}
      {activeTab === "chat" && <Chat profile={profile} config={config} initialTarget={chatTarget} clearInitialTarget={() => setChatTarget(null)} />}
      {activeTab === "notifications" && <Notifications profile={profile} />}
      {activeTab === "admin" && (profile.role === "admin" || profile.role === "super-admin") && <AdminDashboard profile={profile} config={config} />}
      {activeTab === "values" && <Values />}
      {activeTab === "oath" && <Oath />}
      {activeTab === "museum" && config.parrotMuseumEnabled && <ParrotMuseum />}
      {activeTab === "ranking" && (config.rankingEnabled || profile.role !== 'user') && <Ranking profile={profile} config={config} onViewProfile={(u) => {
        setSelectedUserProfile(u);
        setActiveTab("public-profile");
      }} />}
      {activeTab === "culturel" && (config.culturelEnabled || profile.role !== 'user') && <Culturel profile={profile} config={config} />}
      {activeTab === "profile" && <Profile mode="edit" profile={profile} onComplete={(p) => setProfile(p)} />}
    </Layout>
  );
}
