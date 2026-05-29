import { useState, useEffect } from "react";
import { auth, db } from "../firebase";
import { doc, setDoc, getDocs, collection, query, limit } from "firebase/firestore";
import { UserProfile } from "../App";
import { motion } from "motion/react";
import { User, Camera, BookOpen, Heart, Send, CheckCircle2 } from "lucide-react";
import { getDeptTheme, DEPARTMENTS, COMMISSIONS } from "../lib/theme";

interface ProfileProps {
  mode: "create" | "edit";
  profile?: UserProfile;
  onComplete: (profile: UserProfile) => void;
}

export default function Profile({ mode, profile, onComplete }: ProfileProps) {
  const [firstName, setFirstName] = useState(profile?.firstName || auth.currentUser?.displayName?.split(" ")[0] || "");
  const [lastName, setLastName] = useState(profile?.lastName || auth.currentUser?.displayName?.split(" ").slice(1).join(" ") || "");
  const [department, setDepartment] = useState(profile?.department || "");
  const [bio, setBio] = useState(profile?.bio || "");
  const [hobbies, setHobbies] = useState(profile?.hobbies || "");
  const [photoUrl, setPhotoUrl] = useState(profile?.photoUrl || auth.currentUser?.photoURL || "");
  const [selectedCommissions, setSelectedCommissions] = useState<string[]>(
    Array.isArray(profile?.commissions) ? profile.commissions.filter(c => c !== "Deureudj") : []
  );
  const [isDeureudj, setIsDeureudj] = useState<boolean>(
    Array.isArray(profile?.commissions) ? profile.commissions.includes("Deureudj") : false
  );
  const [loading, setLoading] = useState(false);

  const theme = getDeptTheme(department);

  const toggleCommission = (comm: string) => {
    setSelectedCommissions(prev => 
      prev.includes(comm) ? [] : [comm]
    );
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!auth.currentUser) return;
    setLoading(true);

    try {
      // Check if this is the first user to make them super-admin
      let role: "user" | "admin" | "super-admin" = profile?.role || "user";
      if (mode === "create") {
         const usersSnap = await getDocs(query(collection(db, "users"), limit(1)));
         if (usersSnap.empty) {
            role = "super-admin";
            // Also initialize global config if empty
            await setDoc(doc(db, "config", "global"), {
              inscriptionOnly: true,
              showValues: true,
              showOath: true
            }, { merge: true });
         }
      }

      const finalCommissions = [...selectedCommissions];
      if (isDeureudj && !finalCommissions.includes("Deureudj")) {
        finalCommissions.push("Deureudj");
      }

      const updatedProfile: UserProfile = {
        uid: auth.currentUser.uid,
        firstName,
        lastName,
        department,
        bio,
        hobbies,
        photoUrl,
        role,
        isBureauMember: profile?.isBureauMember || false,
        bureauRole: profile?.bureauRole || "",
        commissions: finalCommissions,
        ...(profile?.interactionStats ? { interactionStats: profile.interactionStats } : {}),
        ...(profile?.badges ? { badges: profile.badges } : {})
      };

      await setDoc(doc(db, "users", auth.currentUser.uid), updatedProfile, { merge: true });
      onComplete(updatedProfile);
    } catch (error) {
      console.error("Profile save error:", error);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className={`min-h-screen flex items-center justify-center p-6 py-12 transition-colors duration-500 ${theme.pageBg}`}>
      <motion.div 
        initial={{ opacity: 0, scale: 0.95 }}
        animate={{ opacity: 1, scale: 1 }}
        className="max-w-2xl w-full bg-white rounded-[40px] p-8 md:p-12 shadow-xl border border-black/5"
      >
        <div className="flex flex-col items-center mb-10">
          <div className="relative group">
            <div className={`w-32 h-32 rounded-full overflow-hidden border-4 mb-4 bg-gray-100 ${theme.border}`}>
              {photoUrl ? (
                <img src={photoUrl} alt="Preview" className="w-full h-full object-cover" />
              ) : (
                <div className="w-full h-full flex items-center justify-center text-gray-300">
                  <User size={64} />
                </div>
              )}
            </div>
            <button 
              type="button"
              className={`absolute bottom-4 right-0 p-2 text-white rounded-full shadow-lg hover:scale-110 transition-transform ${theme.bg}`}
              title="Change photo URL"
              onClick={() => {
                const url = prompt("Lien de votre photo :", photoUrl);
                if (url !== null) setPhotoUrl(url);
              }}
            >
              <Camera size={16} />
            </button>
          </div>
          <h1 className="text-3xl font-serif text-[#1a1c1a]">
            {mode === "create" ? "Complétez votre profil" : "Modifier votre profil"}
          </h1>
          <p className="text-gray-500 mt-2">Dites-en un peu plus sur vous à la promotion.</p>
        </div>

        <form onSubmit={handleSubmit} className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="space-y-2">
            <label className="text-sm font-medium text-gray-700 ml-1">Prénom</label>
            <input
              required
              value={firstName}
              onChange={(e) => setFirstName(e.target.value)}
              className={`w-full ${theme.lightBg} border-none rounded-2xl p-4 focus:ring-2 ${theme.ring} outline-none transition-all`}
              placeholder="Ex: Moussa"
            />
          </div>
          <div className="space-y-2">
            <label className="text-sm font-medium text-gray-700 ml-1">Nom</label>
            <input
              required
              value={lastName}
              onChange={(e) => setLastName(e.target.value)}
              className={`w-full ${theme.lightBg} border-none rounded-2xl p-4 focus:ring-2 ${theme.ring} outline-none transition-all`}
              placeholder="Ex: Ndiaye"
            />
          </div>
          <div className="md:col-span-2 space-y-2">
            <label className="text-sm font-medium text-gray-700 ml-1">Département</label>
            <select
              required
              value={department}
              onChange={(e) => setDepartment(e.target.value)}
              className={`w-full ${theme.lightBg} border-none rounded-2xl p-4 focus:ring-2 ${theme.ring} outline-none appearance-none transition-all`}
            >
              <option value="">Sélectionnez votre département</option>
              {DEPARTMENTS.map(dept => (
                <option key={dept} value={dept}>{dept}</option>
              ))}
            </select>
          </div>
          <div className="md:col-span-2 space-y-2">
            <label className="text-sm font-medium text-gray-700 ml-1">Votre histoire / Bio</label>
            <textarea
              value={bio}
              onChange={(e) => setBio(e.target.value)}
              className={`w-full ${theme.lightBg} border-none rounded-3xl p-6 min-h-[120px] focus:ring-2 ${theme.ring} outline-none resize-none transition-all`}
              placeholder="Parlez-nous de vous, de votre parcours..."
            />
          </div>
          <div className="md:col-span-2 space-y-2">
            <label className="text-sm font-medium text-gray-700 ml-1">Passions / Hobbies</label>
            <input
              value={hobbies}
              onChange={(e) => setHobbies(e.target.value)}
              className={`w-full ${theme.lightBg} border-none rounded-2xl p-4 focus:ring-2 ${theme.ring} outline-none transition-all`}
              placeholder="Ex: Basketball, Programmation, Musique..."
            />
          </div>

          {mode === "create" && (
            <>
              <div className="md:col-span-2 space-y-4">
                <label className="text-sm font-bold text-gray-700 ml-1 uppercase tracking-widest">Quelle commission veux-tu rejoindre (1 max) ?</label>
                <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
                  {COMMISSIONS.map(comm => {
                    const isSelected = selectedCommissions.includes(comm);
                    return (
                      <button
                        key={comm}
                        type="button"
                        onClick={() => toggleCommission(comm)}
                        className={`flex items-center gap-2 p-3 rounded-2xl text-xs font-bold transition-all border-2 ${
                          isSelected 
                            ? `${theme.bg} text-white ${theme.border} shadow-md scale-[1.02]` 
                            : "bg-white text-gray-500 border-gray-100 hover:border-gray-200"
                        }`}
                      >
                        {isSelected && <CheckCircle2 size={14} />}
                        {comm}
                      </button>
                    );
                  })}
                </div>
              </div>

              <div className="md:col-span-2 space-y-4 mt-2 bg-slate-50 p-6 rounded-3xl border border-slate-100">
                <p className="text-sm font-bold text-slate-800 uppercase tracking-widest">Voulez-vous postuler pour la commission Deureudj ?</p>
                <div className="flex gap-4">
                  <button
                    type="button"
                    onClick={() => setIsDeureudj(true)}
                    className={`flex-1 py-3 rounded-xl text-sm font-bold transition-all border-2 ${
                      isDeureudj ? "bg-slate-800 text-white border-slate-800" : "bg-white text-slate-500 border-slate-200 hover:border-slate-300"
                    }`}
                  >
                    Oui
                  </button>
                  <button
                    type="button"
                    onClick={() => setIsDeureudj(false)}
                    className={`flex-1 py-3 rounded-xl text-sm font-bold transition-all border-2 ${
                      !isDeureudj ? "bg-slate-800 text-white border-slate-800" : "bg-white text-slate-500 border-slate-200 hover:border-slate-300"
                    }`}
                  >
                    Non
                  </button>
                </div>
              </div>
            </>
          )}

          <div className="md:col-span-2 pt-6">
            <button
              disabled={loading}
              type="submit"
              className={`w-full flex items-center justify-center gap-3 ${department ? theme.bg : 'bg-slate-900'} text-white py-5 rounded-full hover:bg-opacity-90 transition-all font-semibold shadow-lg disabled:opacity-50`}
            >
              {loading ? (
                <div className="w-6 h-6 border-2 border-white/30 border-t-white rounded-full animate-spin" />
              ) : (
                <>
                  <Send size={20} />
                  <span>{mode === "create" ? "Commencer l'aventure" : "Enregistrer les modifications"}</span>
                </>
              )}
            </button>
          </div>
        </form>
      </motion.div>
    </div>
  );
}
