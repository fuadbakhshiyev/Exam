const CONFIG = {
    "Mixed": {
        units: ["Grafik Üretim Teknikleri","Özgün Baskı Teknikleri","Reklam Grafiği","Tasarım Okumaları","Web Tasarımının Temelleri"],
        mixed: [],
        exams: []
    },
    "Grafik Üretim Teknikleri": {
        units: ["Unit 1","Unit 2","Unit 3","Unit 4","Unit 5","Unit 6","Unit 7","Unit 8","Unit 9","Unit 10","Unit 11","Unit 12","Unit 13","Unit 14"],
        mixed: [],
        exams: []
    },
    "Özgün Baskı Teknikleri": {
        units: ["Unit 1","Unit 2","Unit 3","Unit 4","Unit 5","Unit 6","Unit 7","Unit 8","Unit 9","Unit 10","Unit 11","Unit 12","Unit 13","Unit 14"],
        mixed: [],
        exams: []
    },
    "Reklam Grafiği": {
        units: ["Unit 1","Unit 2","Unit 3","Unit 4","Unit 5","Unit 6","Unit 7","Unit 8","Unit 9","Unit 10","Unit 11","Unit 12","Unit 13","Unit 14"],
        mixed: [],
        exams: []
    },
    "Tasarım Okumaları": {
        units: ["Unit 1","Unit 2","Unit 3","Unit 4","Unit 5","Unit 6","Unit 7"],
        mixed: [],
        exams: []
    },
    "Web Tasarımının Temelleri": {
        units: ["Unit 1","Unit 2","Unit 3","Unit 4","Unit 5","Unit 6","Unit 7","Unit 8","Unit 9","Unit 10","Unit 11","Unit 12","Unit 13","Unit 14"],
        mixed: [],
        exams: []
    }
};

// Fənlərin sırası: Mixed suallarında u dəyəri bu siyahıdakı sıra nömrəsidir (1-dən başlayır)
const SUBJECTS = Object.keys(CONFIG).filter(c => c !== "Mixed");

// İnkişaf dinamikası qrafikinin göstərdiyi dövr (ilk və son gün daxil)
const STUDY_PERIOD = { start: "2026-11-03", end: "2026-11-22" };
