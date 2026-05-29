import { useState, useEffect, useRef } from "react";
import { UserProfile } from "../App";
import { db, auth } from "../firebase";
import { 
  collection, 
  query, 
  where, 
  onSnapshot, 
  addDoc, 
  serverTimestamp, 
  orderBy, 
  getDocs,
  doc,
  setDoc,
  updateDoc,
  increment,
  getDoc,
  limit
} from "firebase/firestore";
import { motion, AnimatePresence } from "motion/react";
import { 
  Send, 
  User, 
  Search, 
  MessageCircle, 
  Megaphone,
  Filter,
  CheckCheck,
  Lock
} from "lucide-react";
import { format } from "date-fns";
import { fr } from "date-fns/locale";
import { toast } from "sonner";
import { cn } from "../lib/utils";
import { AppConfig } from "../App";

interface Message {
  id: string;
  senderId: string;
  text: string;
  createdAt: any;
}

interface Conversation {
  id: string;
  participantIds: string[];
  type: "direct" | "group";
  lastMessageAt: any;
  otherUser?: UserProfile;
}

import { getDeptTheme } from "../lib/theme";

export default function Chat({ profile, config, initialTarget, clearInitialTarget }: { 
  profile: UserProfile, 
  config: AppConfig,
  initialTarget?: UserProfile | null,
  clearInitialTarget?: () => void
}) {
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [activeConv, setActiveConv] = useState<Conversation | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [contacts, setContacts] = useState<UserProfile[]>([]);
  const [showContacts, setShowContacts] = useState(false);
  const [newMsg, setNewMsg] = useState("");
  const [searchTerm, setSearchTerm] = useState("");
  const [showBroadcast, setShowBroadcast] = useState(false);
  const [broadcastText, setBroadcastText] = useState("");
  const [broadcastDept, setBroadcastDept] = useState("");

  const scrollRef = useRef<HTMLDivElement>(null);

  const isChatDisabled = config.disableChat && profile.role === 'user';
  const theme = getDeptTheme(profile.department);

  // Load Contacts
  useEffect(() => {
    if (isChatDisabled) return;
    let q;
    if (profile.role === 'user') {
      q = query(collection(db, "users"), where("isBureauMember", "==", true));
    } else {
      q = query(collection(db, "users"), where("role", "==", "user"));
    }
    const unsub = onSnapshot(q, (snap) => {
      const allContacts = snap.docs.map(doc => ({ uid: doc.id, ...doc.data() } as UserProfile));
      setContacts(allContacts.filter(u => u.role !== 'super-admin'));
    });
    return unsub;
  }, [profile, isChatDisabled]);

  // Load Conversations
  useEffect(() => {
    if (isChatDisabled) return;
    const q = query(
      collection(db, "conversations"), 
      where("participantIds", "array-contains", profile.uid),
      orderBy("lastMessageAt", "desc")
    );
    const unsub = onSnapshot(q, async (snap) => {
      const convs = snap.docs.map(doc => ({ id: doc.id, ...doc.data() } as Conversation));
      const resolved = await Promise.all(convs.map(async (c) => {
        if (c.type === "direct") {
          const otherId = c.participantIds.find(id => id !== profile.uid);
          if (otherId) {
            const userSnap = await getDocs(query(collection(db, "users"), where("uid", "==", otherId), limit(1)));
            if (!userSnap.empty) {
              return { ...c, otherUser: { uid: otherId, ...userSnap.docs[0].data() } as UserProfile };
            }
          }
        }
        return c;
      }));
      setConversations(resolved);
      
      // Handle initial target from deep link
      if (initialTarget) {
        const existing = resolved.find(c => 
          c.type === "direct" && c.participantIds.includes(initialTarget.uid)
        );
        if (existing) {
          setActiveConv(existing);
          clearInitialTarget?.();
        } else if (resolved.length > 0) {
          // Only start if we have loaded at least some conversations (to avoid race with empty initial state)
          // or if it's truly a new conversation.
          // Actually, startDirectChat logic should be robust.
          const id = [profile.uid, initialTarget.uid].sort().join("_");
          const newConv = {
            participantIds: [profile.uid, initialTarget.uid],
            type: "direct" as const,
            lastMessageAt: serverTimestamp()
          };
          setDoc(doc(db, "conversations", id), newConv, { merge: true });
          setActiveConv({ id, ...newConv, otherUser: initialTarget });
          clearInitialTarget?.();
        }
      }
    });
    return unsub;
  }, [profile, isChatDisabled, initialTarget]);

  // Load Messages
  useEffect(() => {
    if (!activeConv) {
      setMessages([]);
      return;
    }
    const q = query(
      collection(db, "conversations", activeConv.id, "messages"),
      orderBy("createdAt", "asc")
    );
    const unsub = onSnapshot(q, (snap) => {
      setMessages(snap.docs.map(doc => ({ id: doc.id, ...doc.data() } as Message)));
    });
    return unsub;
  }, [activeConv]);

  useEffect(() => {
    scrollRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  const startDirectChat = async (otherUser: UserProfile) => {
    const existing = conversations.find(c => 
      c.type === "direct" && c.participantIds.includes(otherUser.uid)
    );
    if (existing) {
      setActiveConv(existing);
      setShowContacts(false);
      return;
    }
    const id = [profile.uid, otherUser.uid].sort().join("_");
    const newConv = {
      participantIds: [profile.uid, otherUser.uid],
      type: "direct" as const,
      lastMessageAt: serverTimestamp()
    };
    await setDoc(doc(db, "conversations", id), newConv);
    await updateUserStats(otherUser, true);
    setActiveConv({ id, ...newConv, otherUser });
    setShowContacts(false);
  };

  const sendMessage = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newMsg.trim() || !activeConv) return;
    const msg = {
      senderId: profile.uid,
      text: newMsg,
      createdAt: serverTimestamp(),
      conversationId: activeConv.id
    };
    setNewMsg("");
    await addDoc(collection(db, "conversations", activeConv.id, "messages"), msg);
    await setDoc(doc(db, "conversations", activeConv.id), { 
      lastMessageAt: serverTimestamp(),
      lastSenderId: profile.uid,
      lastMessageText: newMsg 
    }, { merge: true });
    
    // Update Stats
    await updateUserStats(activeConv.otherUser, false);
  };

  const updateUserStats = async (otherUser: UserProfile | undefined, isNewConv: boolean) => {
    if (!otherUser) return;
    
    const userRef = doc(db, "users", profile.uid);
    const isCrossDept = otherUser.department !== profile.department;
    const multiplier = isCrossDept ? 2 : 1;
    let pointsToAdd = isNewConv ? 10 : 1;
    pointsToAdd *= multiplier;

    const updates: any = {
      "interactionStats.points": increment(pointsToAdd),
      "interactionStats.totalMessages": increment(1)
    };

    if (isNewConv) {
      updates["interactionStats.startedConversations"] = increment(1);
    }

    if (isCrossDept) {
      const currentStats = (await getDoc(userRef)).data()?.interactionStats || {};
      const crossDeptInteracted = currentStats.crossDeptInteractions || [];
      if (!crossDeptInteracted.includes(otherUser.uid)) {
        updates["interactionStats.crossDeptInteractions"] = [...crossDeptInteracted, otherUser.uid];
      }
    }

    await updateDoc(userRef, updates);
  };

  const sendBroadcast = async () => {
    if (!broadcastText.trim()) return;
    await addDoc(collection(db, "broadcasts"), {
      senderId: profile.uid,
      text: broadcastText,
      filterDept: broadcastDept || null,
      createdAt: serverTimestamp()
    });
    setBroadcastText("");
    setShowBroadcast(false);
    toast.success("Diffusion réussie !");
  };

  if (isChatDisabled) {
    return (
      <div className="h-full flex flex-col items-center justify-center p-6 text-center bg-white rounded-3xl md:rounded-[40px] border border-slate-200">
        <div className="w-20 h-20 bg-slate-50 rounded-2xl shadow-lg flex items-center justify-center mb-6 text-slate-300">
          <Lock size={40} />
        </div>
        <h2 className="text-xl md:text-2xl font-bold text-slate-800 tracking-tight">Chat Désactivé</h2>
        <p className="mt-4 text-slate-500 max-w-sm text-sm font-medium">
          Les discussions sont suspendues par le bureau.
        </p>
      </div>
    );
  }

  return (
    <div className="h-full flex flex-col md:flex-row rounded-2xl md:rounded-[40px] shadow-2xl shadow-slate-200/50 overflow-hidden border relative transition-colors duration-500 bg-white/50 backdrop-blur-md border-slate-200/60">
      {/* Sidebar */}
      <div className={cn(
        "w-full md:w-72 lg:w-80 border-r flex flex-col transition-all",
        theme.primary.replace('bg-', 'bg-').replace('-600', '-50/50'),
        "border-slate-200/60",
        activeConv && "hidden md:flex"
      )}>
        <div className="p-4 md:p-6 space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-lg md:text-xl font-bold text-slate-800 tracking-tight">Messages</h2>
            <div className="flex gap-2">
               {(profile.role === 'admin' || profile.role === 'super-admin') && (
                 <button onClick={() => setShowBroadcast(true)} className={cn("p-2 bg-white rounded-xl border border-slate-200 shadow-sm transition-all hover:scale-110", theme.text)}>
                   <Megaphone size={18} />
                 </button>
               )}
               {(!config.inscriptionOnly || profile.role !== 'user') && (
                 <button onClick={() => setShowContacts(true)} className={cn("p-2 bg-white rounded-xl border border-slate-200 shadow-sm transition-all hover:scale-110", theme.text)}>
                   <MessageCircle size={18} />
                 </button>
               )}
            </div>
          </div>
          <div className="relative group">
            <Search size={16} className={cn("absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 group-focus-within:" + theme.text)} />
            <input 
              type="text" 
              placeholder="Chercher..."
              className={cn("w-full bg-white border border-slate-200 rounded-xl pl-10 pr-4 py-2 text-sm outline-none focus:ring-2 shadow-sm", theme.ring)}
            />
          </div>
        </div>

        <div className="flex-1 overflow-y-auto px-2 pb-4 space-y-1">
          {conversations.length === 0 ? (
            <div className="text-center py-10 px-4 text-xs text-slate-400 font-bold uppercase tracking-widest italic opacity-50">Aucune discussion</div>
          ) : (
            conversations.map(conv => (
              <button
                key={conv.id}
                onClick={() => setActiveConv(conv)}
                className={cn(
                  "w-full flex items-center gap-3 p-3 rounded-2xl transition-all group text-left",
                  activeConv?.id === conv.id ? "bg-white shadow-md border border-slate-100 scale-[1.02]" : "hover:bg-white/60"
                )}
              >
                <div className="relative shrink-0">
                  <img src={conv.otherUser?.photoUrl || "https://ui-avatars.com/api/?name="+conv.otherUser?.firstName} alt="" className="w-10 h-10 rounded-full object-cover border-2 border-white shadow-sm" />
                  <div className="absolute -bottom-0.5 -right-0.5 w-3 h-3 bg-green-500 rounded-full border-2 border-white shadow-sm" />
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex justify-between items-baseline mb-0.5">
                    <h4 className="font-bold text-slate-800 text-sm truncate">{conv.otherUser?.firstName}</h4>
                    <span className="text-[9px] text-slate-400 font-bold">{conv.lastMessageAt ? format(conv.lastMessageAt.toDate(), "HH:mm") : ""}</span>
                  </div>
                  <p className="text-[10px] text-slate-500 truncate font-semibold uppercase tracking-tighter">{conv.otherUser?.department}</p>
                </div>
              </button>
            ))
          )}
        </div>
      </div>

      {/* Main Chat */}
      <div className={cn("flex-1 flex flex-col bg-slate-50/30", !activeConv && "hidden md:flex")}>
        {activeConv ? (
          <>
            <div className="h-14 md:h-16 border-b border-slate-100 flex items-center justify-between px-4 bg-white/80 backdrop-blur-md shrink-0">
              <div className="flex items-center gap-3">
                <button onClick={() => setActiveConv(null)} className="md:hidden p-1 -ml-1 text-slate-400"><Filter size={18} className="rotate-90" /></button>
                <img src={activeConv.otherUser?.photoUrl || "https://ui-avatars.com/api/?name="+activeConv.otherUser?.firstName} alt="" className="w-8 h-8 rounded-full border-2 border-white shadow-sm" />
                <div className="min-w-0">
                  <h3 className="font-extrabold text-slate-800 text-sm truncate uppercase tracking-tight">{activeConv.otherUser?.firstName} {activeConv.otherUser?.lastName}</h3>
                  <p className={cn("text-[8px] font-bold uppercase tracking-[0.2em] leading-none opacity-60", theme.text)}>{activeConv.otherUser?.department}</p>
                </div>
              </div>
            </div>
            <div className={cn("flex-1 overflow-y-auto p-4 space-y-4", theme.primary.replace('bg-', 'bg-').replace('-600', '-50/20'))}>
              {messages.map((msg) => {
                const isMine = msg.senderId === profile.uid;
                return (
                  <div key={msg.id} className={cn("flex flex-col", isMine ? "items-end" : "items-start")}>
                    <motion.div 
                      initial={{ scale: 0.9, opacity: 0, y: 10 }} 
                      animate={{ scale: 1, opacity: 1, y: 0 }} 
                      className={cn(
                        "max-w-[85%] md:max-w-[70%] px-4 py-2.5 rounded-2xl text-[13px] md:text-sm leading-relaxed shadow-sm transition-all", 
                        isMine ? cn(theme.bubble, "text-white rounded-tr-none shadow-indigo-200") : "bg-white text-slate-700 rounded-tl-none border border-slate-100 shadow-indigo-100/50"
                      )}
                    >
                      {msg.text}
                    </motion.div>
                    <div className="flex items-center gap-1 mt-1 px-1">
                      <span className="text-[8px] text-slate-400 font-bold uppercase">{msg.createdAt ? format(msg.createdAt.toDate(), "HH:mm") : ""}</span>
                      {isMine && <CheckCheck size={10} className={theme.text} />}
                    </div>
                  </div>
                );
              })}
              <div ref={scrollRef} />
            </div>
            <form onSubmit={sendMessage} className="p-3 md:p-4 border-t border-slate-100 bg-white/80 backdrop-blur-md">
              <div className={cn("flex items-center gap-2 bg-white/50 backdrop-blur-sm rounded-xl p-1.5 pl-4 ring-1 ring-slate-200 focus-within:ring-2 shadow-inner transition-all", theme.ring)}>
                <input type="text" value={newMsg} onChange={(e) => setNewMsg(e.target.value)} placeholder="Écrire un message..." className="flex-1 bg-transparent py-1.5 outline-none text-sm placeholder:text-slate-400 font-medium" />
                <button type="submit" disabled={!newMsg.trim()} className={cn("p-2 bg-white rounded-lg shadow-sm border border-slate-200 active:scale-95 transition-all hover:bg-slate-50", theme.text)}><Send size={18} /></button>
              </div>
            </form>
          </>
        ) : (
          <div className="flex-1 flex flex-col items-center justify-center text-center p-8 bg-gradient-to-b from-transparent to-slate-50/50">
            <div className={cn("w-20 h-20 rounded-3xl flex items-center justify-center mb-6 shadow-xl rotate-6 transition-transform hover:rotate-0", theme.primary.replace('bg-', 'bg-').replace('-600', '-50'))}>
               <MessageCircle size={40} className={theme.text} />
            </div>
            <h2 className="text-xl font-bold text-slate-800 tracking-tight uppercase italic">ESP Sekou Chat</h2>
            <p className="text-slate-400 text-xs font-bold uppercase tracking-[0.2em] mt-2">
               <span className="text-sm font-black text-blue-500">E</span>xcellence dans la <span className="text-sm font-black text-blue-500">S</span>olidarité et le <span className="text-sm font-black text-blue-500">P</span>artage
            </p>
          </div>
        )}
      </div>

      {/* Modals */}
      <AnimatePresence>
        {showContacts && (
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-slate-900/40 backdrop-blur-sm">
            <div className="absolute inset-0" onClick={() => setShowContacts(false)} />
            <motion.div initial={{ scale: 0.9, y: 20 }} animate={{ scale: 1, y: 0 }} className="relative w-full max-w-sm bg-white rounded-3xl shadow-2xl overflow-hidden border border-slate-200">
              <div className="p-6 border-b border-slate-100 bg-slate-50">
                <h3 className="font-bold text-slate-800 mb-4">Nouveau Message</h3>
                <div className="relative"><Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
                  <input type="text" placeholder="Chercher..." value={searchTerm} onChange={(e) => setSearchTerm(e.target.value)} className="w-full bg-white border border-slate-200 rounded-xl pl-10 pr-4 py-2 py-2 outline-none text-sm" />
                </div>
              </div>
              <div className="max-h-[300px] overflow-y-auto p-2">
                {contacts.filter(c => (c.firstName + " " + c.lastName).toLowerCase().includes(searchTerm.toLowerCase())).map(c => (
                  <button key={c.uid} onClick={() => startDirectChat(c)} className="w-full flex items-center gap-3 p-3 rounded-2xl hover:bg-slate-50 transition-colors text-left">
                    <img src={c.photoUrl} alt="" className="w-10 h-10 rounded-full object-cover" />
                    <div>
                      <h4 className="font-bold text-slate-800 text-sm">{c.firstName}</h4>
                      <p className="text-[10px] text-slate-400 font-bold uppercase">{c.department}</p>
                    </div>
                  </button>
                ))}
              </div>
            </motion.div>
          </motion.div>
        )}

        {showBroadcast && (
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-slate-900/40 backdrop-blur-sm">
            <div className="absolute inset-0" onClick={() => setShowBroadcast(false)} />
            <motion.div initial={{ scale: 0.9, y: 20 }} animate={{ scale: 1, y: 0 }} className="relative w-full max-w-sm bg-white rounded-3xl shadow-2xl p-6 border border-slate-200">
              <h3 className="text-xl font-bold text-slate-800 mb-6 text-center">Diffusion Bureau</h3>
              <div className="space-y-4">
                <div>
                  <label className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Ciblage</label>
                  <select value={broadcastDept} onChange={(e) => setBroadcastDept(e.target.value)} className="w-full bg-slate-50 border border-slate-200 rounded-xl p-3 text-sm mt-1">
                    <option value="">Tous les départements</option>
                    <option value="Génie Civil">Génie Civil</option>
                    <option value="Génie Électrique">Génie Électrique</option>
                    <option value="Génie Mécanique">Génie Mécanique</option>
                    <option value="Génie Informatique">Génie Informatique</option>
                    <option value="Génie Chimique & Biologie">Génie Chimique</option>
                    <option value="Gestion">Gestion</option>
                  </select>
                </div>
                <div>
                  <label className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Message</label>
                  <textarea value={broadcastText} onChange={(e) => setBroadcastText(e.target.value)} className="w-full bg-slate-50 border border-slate-200 rounded-xl p-4 min-h-[100px] text-sm mt-1 outline-none focus:ring-2 ring-blue-600/10" />
                </div>
                <button onClick={sendBroadcast} className={cn("w-full text-white py-4 rounded-xl font-bold shadow-lg active:scale-95 transition-all flex items-center justify-center gap-2", theme.primary)}>
                  <Send size={18} /> Diffuser
                </button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
