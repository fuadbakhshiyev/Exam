#!/usr/bin/env node
// Exports the web app's question data to bundled JSON for the iOS app.
// Usage: node ios/scripts/export_data.js   (from anywhere)
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const root = path.resolve(__dirname, '..', '..');
const outDir = path.join(root, 'ios', 'Imtahan', 'Resources', 'Data');
const imgSrc = path.join(root, 'img', 'oys');
const imgDst = path.join(root, 'ios', 'Imtahan', 'Resources', 'Images');

function load(file, name) {
  const code = fs.readFileSync(path.join(root, file), 'utf8');
  const ctx = vm.createContext({});
  // `const` declarations are not exposed on the context object; return the binding explicitly.
  return vm.runInContext(`${code}\n;${name}`, ctx, { filename: file });
}

const pick = (q) => ({ c: q.c, u: q.u, q: q.q, o: q.o, a: q.a });
const pickPdf = (q) => ({ q: q.q, o: q.o, a: q.a });

const quizData = load('data.js', 'quizData');
const ataaof = load('testsuallari/ataaof_sorular_data.js', 'ataaofSorularData');
const pdfExams = load('testsuallari/pdf_exams_data.js', 'pdfExamsData');
const pdfFinals = load('testsuallari/pdf_finals_data.js', 'pdfFinalsData');
const config = load('config.js', 'CONFIG');

// Mirrors QuizApp.init: append ataaof only if quizData has no "Mixed" questions.
const all = quizData.slice();
if (!all.some((q) => q.c === 'Mixed')) all.push(...ataaof);

const order = Object.keys(pdfExams);
const exams = {};
for (const s of order) exams[s] = pdfExams[s].map((exam) => exam.map(pickPdf));

fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(path.join(outDir, 'questions.json'), JSON.stringify(all.map(pick)));
fs.writeFileSync(path.join(outDir, 'pdf_exams.json'), JSON.stringify({ order, exams }));

// ---- Final booklets (pdf_finals.json) ----
// Each question gets a unit when possible: the booklet's own "Unite: N" (kept by convert_final_pdfs.py),
// else an exact text match against the subject's quizData questions (unique unit only). 0 = unknown.
// Units beyond the subject's current unit count (e.g. old 14-unit Tasarım Okumaları) become 0.
const named = { nbsp: ' ', amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", rsquo: '’', lsquo: '‘', rdquo: '”', ldquo: '“',
  ndash: '–', mdash: '—', hellip: '…' };
const decode = (t) => String(t || '').replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (m, n) => {
  if (n[0] === '#') return String.fromCodePoint(n[1] === 'x' || n[1] === 'X' ? parseInt(n.slice(2), 16) : parseInt(n.slice(1), 10));
  return named[n] !== undefined ? named[n] : m;
});
const norm = (t) => decode(decode(t)).replace(/<[^>]*>/g, ' ').toLocaleLowerCase('tr')
  .replace(/[ıî]/g, 'i').replace(/i̇/g, 'i').replace(/ö/g, 'o').replace(/[üû]/g, 'u').replace(/ç/g, 'c')
  .replace(/ş/g, 's').replace(/ğ/g, 'g').replace(/â/g, 'a').replace(/[^a-z0-9]+/g, '');
const fullKey = (q) => norm(q.q) + '|' + q.o.map(norm).sort().join('|');

const unitsByText = {};      // subject -> norm(q) -> Set(unit)
for (const q of quizData) {
  if (!config[q.c] || q.c === 'Mixed') continue;
  const m = (unitsByText[q.c] ||= new Map());
  const k = norm(q.q);
  if (!m.has(k)) m.set(k, new Set());
  m.get(k).add(q.u);
}
const bankStems = new Set(), bankFull = new Set();
for (const q of all) { bankStems.add(norm(q.q)); bankFull.add(fullKey(q)); }
for (const s of Object.keys(pdfExams)) for (const e of pdfExams[s]) for (const q of e) { bankStems.add(norm(q.q)); bankFull.add(fullKey(q)); }

const finalOrder = Object.keys(pdfFinals);
const finals = {};
const fstat = { total: 0, fromPdf: 0, fromText: 0, none: 0, newFull: 0, newStem: 0 };
const seenFinal = new Set();
let uniqueNew = 0;
for (const s of finalOrder) {
  const maxU = (config[s] && config[s].units.length) || 0;
  finals[s] = pdfFinals[s].map((exam) => ({
    id: exam.sinavId,
    name: exam.ad,
    questions: exam.questions.map((q) => {
      let u = 0;
      if (q.u >= 1 && q.u <= maxU) { u = q.u; fstat.fromPdf++; }
      else {
        const set = unitsByText[s] && unitsByText[s].get(norm(q.q));
        if (set && set.size === 1) { const [x] = set; if (x >= 1 && x <= maxU) { u = x; fstat.fromText++; } }
      }
      if (!u) fstat.none++;
      fstat.total++;
      const fk = fullKey(q);
      if (!bankFull.has(fk)) { fstat.newFull++; if (!seenFinal.has(fk)) uniqueNew++; }
      if (!bankStems.has(norm(q.q))) fstat.newStem++;
      seenFinal.add(fk);
      return { q: q.q, o: q.o, a: q.a, u };
    }),
  }));
}
fs.writeFileSync(path.join(outDir, 'pdf_finals.json'), JSON.stringify({ order: finalOrder, exams: finals }));

fs.mkdirSync(imgDst, { recursive: true });
let copied = 0;
if (fs.existsSync(imgSrc)) {
  for (const f of fs.readdirSync(imgSrc)) {
    if (f.startsWith('.')) continue;
    fs.copyFileSync(path.join(imgSrc, f), path.join(imgDst, f));
    copied++;
  }
}

console.log(`questions.json: ${all.length} (quizData ${quizData.length} + ataaof ${all.length - quizData.length})`);
console.log(`pdf_exams.json: ${order.length} subjects -> ${order.map((s) => `${s}: ${exams[s].length}`).join(', ')}`);
console.log(`images copied: ${copied}`);
console.log(`pdf_finals.json: ${finalOrder.map((s) => `${s}: ${finals[s].length}`).join(', ')}; ${fstat.total} questions`);
console.log(`  units: booklet ${fstat.fromPdf}, text match ${fstat.fromText}, unknown ${fstat.none}`);
console.log(`  not in app banks: ${fstat.newFull} (question+options; ${uniqueNew} unique), ${fstat.newStem} by question text alone`);
