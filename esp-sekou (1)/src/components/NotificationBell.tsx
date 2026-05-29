import { motion, AnimatePresence } from "motion/react";
import { Bell, Check, Trash2, Megaphone, MessageCircle } from "lucide-react";
import { useState, useEffect } from "react";
import { cn } from "../lib/utils";
import { UserProfile } from "../App";
import { getDeptTheme } from "../lib/theme";
import { format } from "date-fns";
import { fr } from "date-fns/locale";

export interface Notification {
  id: string;
  type: "broadcast" | "message";
  title: string;
  text: string;
  timestamp: any;
  read: boolean;
  link?: string;
  targetTab?: string;
}

interface NotificationBellProps {
  notifications: Notification[];
  theme: any;
  onMarkAsRead: (id: string) => void;
  onMarkAllRead: () => void;
  onClear: (id: string) => void;
  onOpenNotification: (notif: Notification) => void;
}

export default function NotificationBell({ 
  notifications, 
  theme, 
  onMarkAsRead, 
  onMarkAllRead, 
  onClear,
  onOpenNotification 
}: NotificationBellProps) {
  const [isOpen, setIsOpen] = useState(false);
  const unreadCount = notifications.filter(n => !n.read).length;

  return (
    <div className="relative">
      <button 
        onClick={() => setIsOpen(!isOpen)}
        className={cn(
          "p-2 rounded-xl transition-all relative group",
          isOpen ? theme.bg + " text-white" : "text-slate-500 hover:bg-slate-100"
        )}
      >
        <Bell size={22} className={cn("transition-transform group-hover:rotate-12", isOpen && "scale-110")} />
        {unreadCount > 0 && (
          <span className="absolute -top-1 -right-1 flex h-5 w-5 items-center justify-center rounded-full bg-rose-500 text-[10px] font-bold text-white border-2 border-white shadow-lg animate-in zoom-in">
            {unreadCount > 9 ? "9+" : unreadCount}
          </span>
        )}
      </button>

      <AnimatePresence>
        {isOpen && (
          <>
            <motion.div 
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="fixed inset-0 z-40 lg:hidden"
              onClick={() => setIsOpen(false)}
            />
            <motion.div
              initial={{ opacity: 0, scale: 0.95, y: 10, rotateX: -10 }}
              animate={{ opacity: 1, scale: 1, y: 0, rotateX: 0 }}
              exit={{ opacity: 0, scale: 0.95, y: 10 }}
              className="absolute right-[-1.25rem] sm:right-0 mt-3 w-[calc(100vw-2.5rem)] sm:w-80 md:w-96 bg-white rounded-3xl shadow-2xl border border-slate-200 z-50 overflow-hidden"
              style={{ transformOrigin: "top right", perspective: "1000px" }}
            >
              <div className="p-4 md:p-6 border-b border-slate-100 flex items-center justify-between bg-slate-50/50">
                <div>
                  <h3 className="font-extrabold text-slate-800 tracking-tight">Notifications</h3>
                  <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">{unreadCount} non lues</p>
                </div>
                {unreadCount > 0 && (
                  <button 
                    onClick={onMarkAllRead}
                    className={cn("text-[10px] font-bold uppercase tracking-widest px-3 py-1.5 rounded-lg border transition-all hover:shadow-sm", theme.text, theme.border)}
                  >
                    Tout lire
                  </button>
                )}
              </div>

              <div className="max-h-[400px] overflow-y-auto">
                {notifications.length === 0 ? (
                  <div className="p-12 text-center">
                    <div className="w-16 h-16 bg-slate-50 rounded-2xl flex items-center justify-center mx-auto mb-4 text-slate-200">
                      <Bell size={24} />
                    </div>
                    <p className="text-slate-400 text-xs font-bold uppercase tracking-widest">Tout est calme ici</p>
                  </div>
                ) : (
                  <div className="divide-y divide-slate-50">
                    {notifications.map((n) => (
                      <div 
                        key={n.id}
                        className={cn(
                          "p-4 flex gap-4 hover:bg-slate-50 transition-colors relative group cursor-pointer",
                          !n.read && "bg-blue-50/30"
                        )}
                        onClick={() => {
                          onOpenNotification(n);
                          setIsOpen(false);
                        }}
                      >
                         <div className={cn(
                           "shrink-0 w-10 h-10 rounded-xl flex items-center justify-center shadow-sm",
                           n.type === "broadcast" ? "bg-amber-100 text-amber-600" : "bg-indigo-100 text-indigo-600"
                         )}>
                            {n.type === "broadcast" ? <Megaphone size={18} /> : <MessageCircle size={18} />}
                         </div>
                         <div className="flex-1 min-w-0">
                           <div className="flex justify-between items-start mb-0.5">
                             <h4 className={cn("text-xs font-bold truncate pr-6", n.read ? "text-slate-600" : "text-slate-900")}>
                               {n.title}
                             </h4>
                             <span className="text-[10px] text-slate-400 font-medium shrink-0">
                               {n.timestamp ? format(n.timestamp.toDate(), "HH:mm", { locale: fr }) : "..."}
                             </span>
                           </div>
                           <p className="text-[11px] text-slate-500 line-clamp-2 leading-relaxed">
                             {n.text}
                           </p>
                         </div>

                         <div className="absolute right-4 bottom-4 flex gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                            <button 
                              onClick={(e) => {
                                e.stopPropagation();
                                onMarkAsRead(n.id);
                              }}
                              className={cn(
                                "p-1.5 bg-white rounded-lg border border-slate-200 shadow-sm hover:scale-110 active:scale-95 transition-all",
                                n.read ? "text-slate-400" : "text-emerald-500"
                              )}
                              title={n.read ? "Marquer comme non lu" : "Marquer comme lu"}
                            >
                              <Check size={14} className={cn(n.read && "opacity-50")} />
                            </button>
                            <button 
                              onClick={(e) => {
                                e.stopPropagation();
                                onClear(n.id);
                              }}
                              className="p-1.5 bg-white text-rose-500 rounded-lg border border-slate-200 shadow-sm hover:scale-110 active:scale-95 transition-all"
                            >
                              <Trash2 size={14} />
                            </button>
                         </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              {notifications.length > 0 && (
                <div className="p-3 bg-slate-50 border-t border-slate-100 text-center">
                  <button 
                    onClick={() => {
                        setIsOpen(false);
                        onOpenNotification({ targetTab: "notifications" } as any);
                    }}
                    className="text-[10px] font-bold text-slate-400 uppercase tracking-[0.2em] hover:text-slate-600 transition-colors"
                  >
                    Voir toutes les annonces
                  </button>
                </div>
              )}
            </motion.div>
          </>
        )}
      </AnimatePresence>
    </div>
  );
}
