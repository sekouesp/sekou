export const DEPARTMENTS = [
  "Génie Informatique",
  "Génie Civil",
  "Génie Électrique",
  "Génie Mécanique",
  "Génie Chimique et Biologie Appliquée",
  "Gestion"
];

export const COMMISSIONS = [
  "Organisation",
  "Communication",
  "Sante",
  "Culturel"
];

export const getDeptTheme = (dept?: string) => {
  switch (dept) {
    case "Génie Informatique": 
      return {
        primary: "indigo",
        bg: "bg-indigo-600",
        text: "text-indigo-600",
        lightBg: "bg-indigo-50",
        mutedBg: "bg-indigo-100/30",
        darkBg: "bg-indigo-900/5",
        pageBg: "bg-[#f5f7ff]",
        border: "border-indigo-100",
        shadow: "shadow-indigo-500/20",
        gradient: "from-indigo-600 to-blue-600",
        bubble: "bg-indigo-600",
        ring: "focus-within:ring-indigo-600/30",
        light: "bg-indigo-50"
      };
    case "Génie Civil": 
      return {
        primary: "amber",
        bg: "bg-amber-600",
        text: "text-amber-600",
        lightBg: "bg-amber-50",
        mutedBg: "bg-amber-100/30",
        darkBg: "bg-amber-900/5",
        pageBg: "bg-[#fffcf0]",
        border: "border-amber-100",
        shadow: "shadow-amber-500/20",
        gradient: "from-amber-600 to-orange-600",
        bubble: "bg-amber-600",
        ring: "focus-within:ring-amber-600/30",
        light: "bg-amber-50"
      };
    case "Génie Électrique": 
      return {
        primary: "cyan",
        bg: "bg-cyan-600",
        text: "text-cyan-600",
        lightBg: "bg-cyan-50",
        mutedBg: "bg-cyan-100/30",
        darkBg: "bg-cyan-900/5",
        pageBg: "bg-[#f0fcfd]",
        border: "border-cyan-100",
        shadow: "shadow-cyan-500/20",
        gradient: "from-cyan-600 to-blue-500",
        bubble: "bg-cyan-600",
        ring: "focus-within:ring-cyan-600/30",
        light: "bg-cyan-50"
      };
    case "Génie Mécanique": 
      return {
        primary: "slate",
        bg: "bg-slate-700",
        text: "text-slate-700",
        lightBg: "bg-slate-100",
        mutedBg: "bg-slate-200/30",
        darkBg: "bg-slate-900/5",
        pageBg: "bg-[#f8fafc]",
        border: "border-slate-200",
        shadow: "shadow-slate-500/20",
        gradient: "from-slate-700 to-slate-900",
        bubble: "bg-slate-700",
        ring: "focus-within:ring-slate-700/30",
        light: "bg-slate-50"
      };
    case "Génie Chimique & Biologie": 
    case "Génie Chimique et Biologie Appliquée": 
      return {
        primary: "emerald",
        bg: "bg-emerald-600",
        text: "text-emerald-600",
        lightBg: "bg-emerald-50",
        mutedBg: "bg-emerald-100/30",
        darkBg: "bg-emerald-900/5",
        pageBg: "bg-[#f0fdf4]",
        border: "border-emerald-100",
        shadow: "shadow-emerald-500/20",
        gradient: "from-emerald-600 to-teal-600",
        bubble: "bg-emerald-600",
        ring: "focus-within:ring-emerald-600/30",
        light: "bg-emerald-50"
      };
    case "Gestion": 
      return {
        primary: "rose",
        bg: "bg-rose-600",
        text: "text-rose-600",
        lightBg: "bg-rose-50",
        mutedBg: "bg-rose-100/30",
        darkBg: "bg-rose-900/5",
        pageBg: "bg-[#fff1f2]",
        border: "border-rose-100",
        shadow: "shadow-rose-500/20",
        gradient: "from-rose-600 to-pink-600",
        bubble: "bg-rose-600",
        ring: "focus-within:ring-rose-600/30",
        light: "bg-rose-50"
      };
    default: 
      return {
        primary: "blue",
        bg: "bg-blue-600",
        text: "text-blue-600",
        lightBg: "bg-blue-50",
        mutedBg: "bg-blue-100/30",
        darkBg: "bg-blue-900/5",
        pageBg: "bg-[#f8fbff]",
        border: "border-blue-100",
        shadow: "shadow-blue-500/20",
        gradient: "from-blue-600 to-indigo-600",
        bubble: "bg-blue-600",
        ring: "focus-within:ring-blue-600/30",
        light: "bg-blue-50"
      };
  }
};
