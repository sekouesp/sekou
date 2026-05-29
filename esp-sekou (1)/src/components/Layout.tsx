import { ReactNode, useRef, useEffect } from "react";
import { UserProfile, AppConfig } from "../App";
import { auth } from "../firebase";
import { signOut } from "firebase/auth";
import { cn } from "../lib/utils";
import { 
  Home, 
  MessageSquare, 
  ShieldCheck, 
  Heart, 
  BookOpen, 
  UserCircle, 
  LogOut, 
  Menu, 
  X,
  Bell,
  Search,
  Trophy,
  Music,
  Bird
} from "lucide-react";
import { useState } from "react";
import { motion, AnimatePresence } from "motion/react";

import { getDeptTheme } from "../lib/theme";
import NotificationBell, { Notification } from "./NotificationBell";

interface LayoutProps {
  children: ReactNode;
  profile: UserProfile;
  config: AppConfig;
  activeTab: string;
  setActiveTab: (tab: string) => void;
  notifications?: Notification[];
  onMarkAsRead?: (id: string) => void;
  onMarkAllRead?: () => void;
  onClear?: (id: string) => void;
  onOpenNotification?: (n: Notification) => void;
}

export default function Layout({ 
  children, 
  profile, 
  config, 
  activeTab, 
  setActiveTab,
  notifications = [],
  onMarkAsRead = () => {},
  onMarkAllRead = () => {},
  onClear = () => {},
  onOpenNotification = () => {}
}: LayoutProps) {
  const [isSidebarOpen, setIsSidebarOpen] = useState(false);
  const mainRef = useRef<HTMLElement>(null);
  const theme = getDeptTheme(profile.department);

  useEffect(() => {
    if (mainRef.current) {
      mainRef.current.scrollTo(0, 0);
    }
  }, [activeTab]);

  const navItems = [
    { id: "home", label: "Accueil", icon: Home, visible: true },
    { id: "chat", label: "Conversations", icon: MessageSquare, visible: !config.disableChat },
    { id: "notifications", label: "Annonces", icon: Bell, visible: config.annoncesEnabled !== false },
    { id: "ranking", label: "Classement", icon: Trophy, visible: config.rankingEnabled !== false },
    { id: "culturel", label: "Culturel", icon: Music, visible: config.culturelEnabled !== false },
    { id: "museum", label: "Musée", icon: Bird, visible: config.parrotMuseumEnabled === true },
    { id: "values", label: "Valeurs", icon: Heart, visible: config.showValues },
    { id: "oath", label: "Serment", icon: BookOpen, visible: config.showOath },
    { id: "admin", label: "Gestion bureau", icon: ShieldCheck, visible: profile.role === "admin" || profile.role === "super-admin" },
    { id: "profile", label: "Mon Profil", icon: UserCircle, visible: true },
  ];

  const coreNavIds = ["home", "chat", "ranking", "profile"];

  const handleLogout = () => signOut(auth);

  return (
    <div className={cn("flex h-screen overflow-hidden font-sans transition-colors duration-500", theme.pageBg)}>
      {/* Mobile Header */}
      {!["public-profile"].includes(activeTab) && (
        <div className={cn(
          "lg:hidden fixed top-0 left-0 right-0 h-16 border-b flex items-center justify-between px-5 z-40 transition-all duration-300 backdrop-blur-xl",
          isSidebarOpen ? "opacity-0 pointer-events-none" : "opacity-100",
          theme.lightBg.replace('/10', '/80'),
          theme.border.replace('-100', '-200/50')
        )}>
          <div className="flex items-center gap-3" onClick={() => setActiveTab("home")}>
            <div className="relative">
              <div className={cn("absolute inset-0 blur-lg opacity-20 rounded-full", theme.bg)}></div>
              <img src="https://res.cloudinary.com/dkpqkwjgo/image/upload/v1779016358/esp_sekou_logo_nobg_yh1xt7.png" alt="ESP" className="w-9 h-9 object-contain relative z-10" />
            </div>
            <div className="flex flex-col">
              <span className="font-black tracking-tight text-sm text-slate-800 uppercase italic leading-none">ESP SEKOU</span>
              <span className={cn("text-[7px] font-bold uppercase tracking-[0.3em]", theme.text)}>Polytech Dakar</span>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <button 
              onClick={() => setIsSidebarOpen(true)} 
              className={cn("p-2.5 rounded-2xl transition-all active:scale-90 bg-white border border-slate-200 shadow-sm", theme.text)}
            >
              <Menu size={20} strokeWidth={2.5} />
            </button>
            <NotificationBell 
              notifications={notifications}
              theme={theme}
              onMarkAsRead={onMarkAsRead}
              onMarkAllRead={onMarkAllRead}
              onClear={onClear}
              onOpenNotification={onOpenNotification}
            />
          </div>
        </div>
      )}

      {/* Sidebar Overlay */}
      <AnimatePresence>
        {isSidebarOpen && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={() => setIsSidebarOpen(false)}
            className="lg:hidden fixed inset-0 bg-slate-900/60 backdrop-blur-md z-50"
          />
        )}
      </AnimatePresence>

      {/* Sidebar */}
      <aside className={cn(
        "fixed lg:static inset-y-0 left-0 w-64 md:w-72 border-r flex flex-col z-[51] transition-all duration-300 transform lg:translate-x-0 shadow-2xl lg:shadow-none",
        theme.lightBg,
        theme.border,
        isSidebarOpen ? "translate-x-0" : "-translate-x-full"
      )}>
        <div className="p-8 flex flex-col items-center gap-6 relative">
          <div className="relative group cursor-pointer" onClick={() => setActiveTab("home")}>
            {/* Sophisticated Glow */}
            <div className={cn("absolute -inset-6 rounded-full blur-3xl opacity-10 group-hover:opacity-25 transition-opacity duration-1000", theme.bg)}></div>
            
            <div className="relative">
              {/* Decorative spinning ring */}
              <div className={cn("absolute -inset-2 rounded-full border border-dashed opacity-10 animate-[spin_30s_linear_infinite]", theme.border)}></div>
              
              <div className="relative p-3.5 rounded-[32px] bg-white shadow-[0_20px_50px_-12px_rgba(0,0,0,0.12)] border border-white/50 transition-all duration-700 group-hover:shadow-[0_40px_80px_-12px_rgba(0,0,0,0.18)] group-hover:-translate-y-2 group-hover:scale-[1.02]">
                 <img 
                    src="https://res.cloudinary.com/dkpqkwjgo/image/upload/v1779016358/esp_sekou_logo_nobg_yh1xt7.png" 
                    alt="ESP SEKOU" 
                    className="w-16 h-16 md:w-20 md:h-20 object-contain drop-shadow-xl" 
                 />
              </div>
            </div>
          </div>
          
          <div className="text-center space-y-1.5 px-2">
            <h1 className="font-black text-2xl text-slate-900 tracking-tighter uppercase italic leading-none">
              ESP <span className={theme.text}>SEKOU</span>
            </h1>
          </div>

          <button onClick={() => setIsSidebarOpen(false)} className="lg:hidden absolute top-4 right-4 p-2.5 text-slate-400 hover:bg-white rounded-2xl transition-all border border-transparent hover:border-slate-100 shadow-sm active:scale-90">
            <X size={18} strokeWidth={2.5} />
          </button>
        </div>

        <nav className="flex-1 px-4 py-2 space-y-1 overflow-y-auto">
          {navItems.filter(i => i.visible).map((item) => (
            <button
              key={item.id}
              onClick={() => {
                setActiveTab(item.id);
                setIsSidebarOpen(false);
              }}
              className={cn(
                "w-full flex items-center gap-3.5 px-4 py-3.5 rounded-2xl transition-all duration-200 group text-sm font-bold tracking-tight",
                coreNavIds.includes(item.id) ? "hidden lg:flex" : "flex",
                activeTab === item.id 
                  ? cn(theme.bg, "text-white shadow-lg", theme.shadow) 
                  : cn("text-slate-500 hover:bg-white hover:text-slate-800", theme.text && "hover:" + theme.text)
              )}
            >
              <item.icon size={20} className={cn(
                "transition-transform group-hover:scale-110",
                activeTab === item.id ? "text-white" : "text-slate-400 group-hover:text-slate-600"
              )} />
              <span>{item.label}</span>
            </button>
          ))}
        </nav>

        <div className={cn("p-4 md:p-6 border-t mt-auto", theme.darkBg, theme.border)}>
          <div className="flex items-center gap-3 mb-4 p-3 rounded-2xl bg-white border border-slate-200 shadow-sm">
            <div className={cn(
              "shrink-0 w-10 h-10 rounded-xl flex items-center justify-center font-bold text-white shadow-md overflow-hidden",
              theme.bg
            )}>
              {profile.photoUrl ? (
                <img src={profile.photoUrl} alt="" className="w-full h-full object-cover" />
              ) : (
                profile.firstName[0] + (profile.lastName[0] || "")
              )}
            </div>
            <div className="flex flex-col min-w-0">
              <span className="text-sm font-bold text-slate-800 truncate leading-none mb-1">{profile.firstName} {profile.lastName}</span>
              <span className="text-[10px] text-slate-400 font-bold uppercase tracking-widest truncate">
                {profile.department || "Étudiant"}
              </span>
            </div>
          </div>
          
          <button 
            onClick={handleLogout}
            className="w-full flex items-center gap-3 px-4 py-3 rounded-2xl text-slate-400 hover:bg-rose-50 hover:text-rose-600 transition-all text-sm font-bold tracking-tight"
          >
            <LogOut size={18} />
            <span>Déconnexion</span>
          </button>
        </div>
      </aside>

      {/* Main Content */}
      <main 
        ref={mainRef}
        className={cn(
          "flex-1 flex flex-col min-w-0 overflow-y-auto relative pb-20 lg:pb-0",
          activeTab === "public-profile" ? "pt-0" : "pt-16 lg:pt-0"
        )}
      >
        {/* Desktop Header */}
        {!["public-profile"].includes(activeTab) && (
          <header className="hidden lg:flex h-24 items-center justify-end px-12 border-b border-slate-200/60 sticky top-0 bg-white/40 backdrop-blur-xl z-40 transition-all pt-2">
             <div className="flex items-center gap-6">
                <div className="flex items-center gap-6">
                  <button 
                    onClick={() => setActiveTab("profile")}
                    className="flex items-center gap-4 pl-3 pr-1.5 py-1.5 rounded-2xl hover:bg-white hover:shadow-2xl hover:shadow-slate-200/50 transition-all group border border-transparent hover:border-slate-100"
                  >
                    <div className="text-right hidden xl:block">
                       <p className="text-sm font-black text-slate-800 leading-none group-hover:text-indigo-600 transition-colors uppercase italic tracking-tight">{profile.firstName} {profile.lastName}</p>
                       <p className={cn("text-[8px] font-bold uppercase tracking-[0.3em] mt-2 opacity-60", theme.text)}>Polytechnicien</p>
                    </div>
                    <div className={cn("w-11 h-11 rounded-2xl overflow-hidden border-2 border-white shadow-xl group-hover:rotate-3 transition-transform", theme.bg)}>
                        <img 
                          src={profile.photoUrl || "https://ui-avatars.com/api/?name=" + profile.firstName} 
                          alt="" 
                          className="w-full h-full object-cover" 
                        />
                    </div>
                  </button>

                  <div className="h-8 w-px bg-slate-200/80 mx-2" />

                  <NotificationBell 
                    notifications={notifications}
                    theme={theme}
                    onMarkAsRead={onMarkAsRead}
                    onMarkAllRead={onMarkAllRead}
                    onClear={onClear}
                    onOpenNotification={onOpenNotification}
                  />
                </div>
             </div>
          </header>
        )}

        <div className={cn(
          "p-3 sm:p-4 md:p-8 lg:p-10 max-w-7xl mx-auto w-full h-full",
        )}>
          {children}
        </div>
      </main>

      {/* Bottom Navigation for Mobile */}
      {!["public-profile"].includes(activeTab) && (
        <nav 
          className="lg:hidden fixed bottom-0 left-0 right-0 bg-white/90 backdrop-blur-xl border-t border-slate-200/60 z-40 shadow-[0_-10px_40px_rgba(0,0,0,0.05)] pt-1"
          style={{ paddingBottom: 'calc(env(safe-area-inset-bottom) + 0.5rem)' }}
        >
          <div className="flex justify-around items-center h-14 px-1">
            {navItems.filter(i => i.visible && coreNavIds.includes(i.id)).map(item => {
              const isActive = activeTab === item.id;
              return (
                <button
                  key={item.id}
                  onClick={() => setActiveTab(item.id)}
                  className={cn(
                    "flex flex-col items-center justify-center w-full h-full gap-1 active:scale-95 transition-all text-slate-400",
                    isActive ? theme.text : "hover:text-slate-600"
                  )}
                >
                  <div className={cn("p-1.5 rounded-xl transition-all", isActive ? cn(theme.bg, "text-white shadow-md", theme.shadow) : "")}>
                    <item.icon size={20} strokeWidth={isActive ? 2.5 : 2} className={isActive ? "" : ""} />
                  </div>
                  <span className={cn("text-[9px] font-bold tracking-wider uppercase", isActive ? "" : "opacity-80")}>
                    {item.label === "Conversations" ? "Messages" : item.label === "Mon Profil" ? "Profil" : item.label}
                  </span>
                </button>
              );
            })}
          </div>
        </nav>
      )}
    </div>
  );
}
