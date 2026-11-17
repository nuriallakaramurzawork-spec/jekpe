// =====================================================================
// JEKPE — шаблоны весовых категорий и систем сеток
// Веса — максимальный вес категории; "+N" — свыше N кг.
// Источники: IBJJF, JJIF, IJF, UWW, FIAS, WKF. Перед турниром сверяйте с регламентом.
// =====================================================================
window.JEKPE_PRESETS = {
  bjj: {
    bracket: "single_2bronze",
    belts: ["white", "blue", "purple", "brown", "black"],
    groups: [
      { id: "adult_gi", label: { ru: "Взрослые 18+ · Gi (IBJJF)", kz: "Ересектер 18+ · Gi (IBJJF)", en: "Adult 18+ · Gi (IBJJF)" }, age: [18, null],
        time: { white: 300, blue: 360, purple: 420, brown: 480, black: 600 },
        m: [57.5, 64, 70, 76, 82.3, 88.3, 94.3, 100.5, "+100.5"], f: [48.5, 53.5, 58.5, 64, 69, 74, 79.3, "+79.3"] },
      { id: "adult_nogi", label: { ru: "Взрослые 18+ · No-Gi (IBJJF)", kz: "Ересектер 18+ · No-Gi (IBJJF)", en: "Adult 18+ · No-Gi (IBJJF)" }, age: [18, null],
        time: { white: 300, blue: 360, purple: 420, brown: 480, black: 600 },
        m: [55.5, 61.5, 67.5, 73.5, 79.5, 85.5, 91.5, 97.5, "+97.5"], f: [46.5, 51.5, 56.5, 61.5, 66.5, 71.5, 76.5, "+76.5"] },
      { id: "master", label: { ru: "Мастера 30+ · Gi", kz: "Шеберлер 30+ · Gi", en: "Masters 30+ · Gi" }, age: [30, null], time: 300,
        m: [57.5, 64, 70, 76, 82.3, 88.3, 94.3, 100.5, "+100.5"], f: [48.5, 53.5, 58.5, 64, 69, 74, 79.3, "+79.3"] },
      { id: "juvenile", label: { ru: "Юниоры 16–17 · Gi", kz: "Жасөспірімдер 16–17 · Gi", en: "Juvenile 16–17 · Gi" }, age: [16, 17], time: 300,
        m: [53.5, 58.5, 64, 69, 74, 79.3, 84.3, 89.3, "+89.3"], f: [44.3, 48.3, 52.5, 56.5, 60.5, 65, 69, "+69"] }
    ]
  },
  newaza: {
    bracket: "single_2bronze",
    belts: ["white", "blue", "purple", "brown", "black"],
    groups: [
      { id: "adult", label: { ru: "Взрослые / U21 (JJIF)", kz: "Ересектер / U21 (JJIF)", en: "Adults / U21 (JJIF)" }, age: [18, null], time: 360,
        m: [56, 62, 69, 77, 85, 94, "+94"], f: [45, 48, 52, 57, 63, 70, "+70"] },
      { id: "u18", label: { ru: "Кадеты U18 (JJIF)", kz: "Кадеттер U18 (JJIF)", en: "Cadets U18 (JJIF)" }, age: [15, 17], time: 240,
        m: [55, 60, 66, 73, 81, 90, "+90"], f: [44, 48, 52, 57, 63, 70, "+70"] }
    ]
  },
  judo: {
    bracket: "repechage_judo",
    groups: [
      { id: "senior", label: { ru: "Взрослые / U21 (IJF)", kz: "Ересектер / U21 (IJF)", en: "Seniors / U21 (IJF)" }, age: [15, null], time: 240,
        m: [60, 66, 73, 81, 90, 100, "+100"], f: [48, 52, 57, 63, 70, 78, "+78"] },
      { id: "cadet", label: { ru: "Кадеты U18 (IJF)", kz: "Кадеттер U18 (IJF)", en: "Cadets U18 (IJF)" }, age: [15, 17], time: 240,
        m: [50, 55, 60, 66, 73, 81, 90, "+90"], f: [40, 44, 48, 52, 57, 63, 70, "+70"] }
    ]
  },
  free: {
    bracket: "repechage_full",
    groups: [
      { id: "senior", label: { ru: "Взрослые / U23 / U20 (UWW)", kz: "Ересектер / U23 / U20 (UWW)", en: "Seniors / U23 / U20 (UWW)" }, age: [17, null], time: 180,
        m: [57, 61, 65, 70, 74, 79, 86, 92, 97, 125], f: [50, 53, 55, 57, 59, 62, 65, 68, 72, 76] },
      { id: "u17", label: { ru: "Кадеты U17 (UWW)", kz: "Кадеттер U17 (UWW)", en: "Cadets U17 (UWW)" }, age: [15, 17], time: 120,
        m: [45, 48, 51, 55, 60, 65, 71, 80, 92, 110], f: [40, 43, 46, 49, 53, 57, 61, 65, 69, 73] }
    ]
  },
  greco: {
    bracket: "repechage_full",
    groups: [
      { id: "senior", label: { ru: "Взрослые / U23 / U20 (UWW)", kz: "Ересектер / U23 / U20 (UWW)", en: "Seniors / U23 / U20 (UWW)" }, age: [17, null], time: 180,
        m: [55, 60, 63, 67, 72, 77, 82, 87, 97, 130], f: [] },
      { id: "u17", label: { ru: "Кадеты U17 (UWW)", kz: "Кадеттер U17 (UWW)", en: "Cadets U17 (UWW)" }, age: [15, 17], time: 120,
        m: [45, 48, 51, 55, 60, 65, 71, 80, 92, 110], f: [] }
    ]
  },
  sambo: {
    bracket: "repechage_full",
    groups: [
      { id: "adult", label: { ru: "Взрослые и юниоры 18+ (FIAS)", kz: "Ересектер мен жастар 18+ (FIAS)", en: "Adults & Juniors 18+ (FIAS)" }, age: [18, null], time: 300,
        m: [58, 64, 71, 79, 88, 98, "+98"], f: [50, 54, 59, 65, 72, 80, "+80"] },
      { id: "youth", label: { ru: "Юноши 16–18 (FIAS)", kz: "Жасөспірімдер 16–18 (FIAS)", en: "Youth 16–18 (FIAS)" }, age: [16, 18], time: 240,
        m: [53, 58, 64, 71, 79, 88, 98, "+98"], f: [47, 50, 54, 59, 65, 72, 80, "+80"] },
      { id: "cadet", label: { ru: "Кадеты 14–16 (FIAS)", kz: "Кадеттер 14–16 (FIAS)", en: "Cadets 14–16 (FIAS)" }, age: [14, 16], time: 240,
        m: [46, 49, 53, 58, 64, 71, 79, 88, "+88"], f: [41, 44, 47, 50, 54, 59, 65, 72, "+72"] }
    ]
  },
  karate: {
    bracket: "repechage_full",
    groups: [
      { id: "senior", label: { ru: "Взрослые / U21 · кумите (WKF)", kz: "Ересектер / U21 · кумите (WKF)", en: "Seniors / U21 · kumite (WKF)" }, age: [18, null], time: 180,
        m: [60, 67, 75, 84, "+84"], f: [50, 55, 61, 68, "+68"] },
      { id: "junior", label: { ru: "Юниоры 16–17 · кумите (WKF)", kz: "Жасөспірімдер 16–17 · кумите (WKF)", en: "Juniors 16–17 · kumite (WKF)" }, age: [16, 17], time: 120,
        m: [55, 61, 68, 76, "+76"], f: [48, 53, 59, 66, "+66"] },
      { id: "cadet", label: { ru: "Кадеты 14–15 · кумите (WKF)", kz: "Кадеттер 14–15 · кумите (WKF)", en: "Cadets 14–15 · kumite (WKF)" }, age: [14, 15], time: 120,
        m: [52, 57, 63, 70, "+70"], f: [47, 54, 61, "+61"] }
    ]
  }
};

window.JEKPE_BRACKETS = ["single", "single_2bronze", "repechage_judo", "repechage_full", "double", "round_robin", "pools", "best_of_3"];
