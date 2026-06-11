const fs = require('fs');
const path = require('path');

const jsonPath = path.join(__dirname, 'testsuallari', 'ataaof_sorular.json');
const rawData = fs.readFileSync(jsonPath, 'utf8');
const data = JSON.parse(rawData);

const subjects = [
  'Atatürk İlkeleri ve İnkılap Tarihi II',
  'Grafik Tasarım II',
  'Görsel İletişim Tasarımı',
  'Masaüstü Yayıncılık',
  'Tasarımda Tipografi',
  'Türk Dili II'
];

const parsedQuestions = [];

subjects.forEach((subject, subjectIndex) => {
  const subjectData = data.dersler[subject];
  if (!subjectData) {
    console.warn(`Subject not found in JSON: ${subject}`);
    return;
  }
  
  const unitNum = subjectIndex + 1; // 1-based unit index
  
  subjectData.sorular.forEach(q => {
    // Collect options
    const options = [q.A, q.B, q.C, q.D, q.E].filter(o => o !== undefined && o !== null);
    
    // Correct index: A -> 0, B -> 1, C -> 2, etc.
    let correctIdx = -1;
    if (q.DogruCevap === 'A') correctIdx = 0;
    else if (q.DogruCevap === 'B') correctIdx = 1;
    else if (q.DogruCevap === 'C') correctIdx = 2;
    else if (q.DogruCevap === 'D') correctIdx = 3;
    else if (q.DogruCevap === 'E') correctIdx = 4;
    else {
      // Fallback
      correctIdx = (q.DogruCevapSirasi !== undefined) ? (q.DogruCevapSirasi - 1) : 0;
    }
    
    parsedQuestions.push({
      c: "Mixed",
      u: unitNum,
      q: q.SoruMetni,
      o: options,
      a: correctIdx
    });
  });
});

const outPath = path.join(__dirname, 'testsuallari', 'ataaof_sorular_data.js');
fs.writeFileSync(outPath, `const ataaofSorularData = ${JSON.stringify(parsedQuestions, null, 2)};\n`);
console.log(`Successfully parsed ${parsedQuestions.length} questions.`);
