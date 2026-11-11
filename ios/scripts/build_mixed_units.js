#!/usr/bin/env node
// Builds ios/Imtahan/Resources/Data/mixed_units.json: the unit number of every "Mixed" question.
//
// Mixed questions (c === "Mixed") carry the SUBJECT index in `u`, not a unit. The exam-scope mode
// (Vize = units 1–7, Final = all) needs the real unit, so each Mixed question's text is matched against
//   (a) the subject's own questions in questions.json (they have real units), then
//   (b) the official ATA AÖF question pool ({subject: [{SoruMetni, Unite, ...}]}), if given.
// Matching uses a normalised text (tags stripped, entities decoded, whitespace collapsed, lowercased),
// then a looser key (punctuation removed, Turkish letters folded) as a fallback.
//
// Output: { "<FNV-1a hash of q.q (QuestionHash.hash)>": unit, ... } for mapped Mixed questions only.
// Unmapped Mixed questions are left out (the app treats them as in scope in every mode).
//
// Usage: node ios/scripts/build_mixed_units.js [path/to/ataaof_havuz.json]
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..', '..');
const dataDir = path.join(root, 'ios', 'Imtahan', 'Resources', 'Data');
const subjects = ['Grafik Üretim Teknikleri', 'Özgün Baskı Teknikleri', 'Reklam Grafiği', 'Tasarım Okumaları', 'Web Tasarımının Temelleri'];

// FNV-1a 32-bit over UTF-16 code units, base 36 (same as QuestionHash.hash / firebase.js).
function hash(s) {
  let h = 0x811c9dc5;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return (h >>> 0).toString(36);
}

const named = { nbsp: ' ', amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", rsquo: '’', lsquo: '‘', rdquo: '”', ldquo: '“',
  ndash: '–', mdash: '—', hellip: '…', ouml: 'ö', Ouml: 'Ö', uuml: 'ü', Uuml: 'Ü', ccedil: 'ç', Ccedil: 'Ç', scedil: 'ş',
  Scedil: 'Ş', acirc: 'â', icirc: 'î', ucirc: 'û', eacute: 'é', laquo: '«', raquo: '»', middot: '·', shy: '' };
function decode(s) {
  return s.replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (m, n) => {
    if (n[0] === '#') return String.fromCodePoint(n[1] === 'x' || n[1] === 'X' ? parseInt(n.slice(2), 16) : parseInt(n.slice(1), 10));
    return named[n] !== undefined ? named[n] : m;
  });
}
// Decode first (the pool escapes markup as entities), then strip tags.
const strict = (t) => decode(decode(String(t || ''))).replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim().toLowerCase();
const loose = (t) => strict(t)
  .replace(/[ıİî]/g, 'i').replace(/i̇/g, 'i').replace(/[öÖ]/g, 'o').replace(/[üÜû]/g, 'u').replace(/[çÇ]/g, 'c')
  .replace(/[şŞ]/g, 's').replace(/[ğĞ]/g, 'g').replace(/â/g, 'a')
  .replace(/[^a-z0-9]+/g, ' ').trim();

const questions = JSON.parse(fs.readFileSync(path.join(dataDir, 'questions.json'), 'utf8'));
const poolPath = process.argv[2];
const pool = poolPath && fs.existsSync(poolPath) ? JSON.parse(fs.readFileSync(poolPath, 'utf8')) : {};
if (poolPath && !fs.existsSync(poolPath)) console.warn(`pool not found: ${poolPath} (matching against questions.json only)`);

// Per subject: strict/loose text -> set of units.
function index(entries) {
  const s = new Map(), l = new Map();
  const add = (m, k, u) => { if (!k) return; if (!m.has(k)) m.set(k, new Set()); m.get(k).add(u); };
  for (const [text, u] of entries) { add(s, strict(text), u); add(l, loose(text), u); }
  return { s, l };
}
const own = {}, aof = {};
for (const subj of subjects) {
  own[subj] = index(questions.filter((q) => q.c === subj && q.u > 0).map((q) => [q.q, q.u]));
  aof[subj] = index((pool[subj] || []).filter((x) => Number(x.Unite) > 0).map((x) => [x.SoruMetni, Number(x.Unite)]));
}

const out = {};
const stats = {};
const conflicts = [];
for (const q of questions) {
  if (q.c !== 'Mixed') continue;
  const subj = subjects[q.u - 1];
  const st = (stats[subj] = stats[subj] || { total: 0, own: 0, aof: 0, unmapped: 0, vize: 0, final: 0 });
  st.total++;
  let units = null, src = null;
  for (const [name, idx] of [['own', own[subj]], ['aof', aof[subj]]]) {
    if (!idx) continue;
    units = idx.s.get(strict(q.q)) || idx.l.get(loose(q.q));
    if (units) { src = name; break; }
  }
  if (!units) { st.unmapped++; continue; }
  st[src]++;
  // A text found in several units: keep the lowest (it is in scope as soon as any copy is).
  const u = Math.min(...units);
  if (units.size > 1) conflicts.push(`${subj}: ${[...units].join('/')} -> ${u}`);
  const h = hash(q.q);
  if (out[h] !== undefined && out[h] !== u) conflicts.push(`hash ${h}: ${out[h]} vs ${u}`);
  out[h] = out[h] === undefined ? u : Math.min(out[h], u);
  if (u <= 7) st.vize++; else st.final++;
}

const sorted = Object.fromEntries(Object.keys(out).sort().map((k) => [k, out[k]]));
fs.writeFileSync(path.join(dataDir, 'mixed_units.json'), JSON.stringify(sorted));

let mapped = 0, unmapped = 0;
for (const subj of subjects) {
  const s = stats[subj] || { total: 0, own: 0, aof: 0, unmapped: 0, vize: 0, final: 0 };
  mapped += s.own + s.aof; unmapped += s.unmapped;
  console.log(`${subj}: ${s.total} Mixed · own ${s.own} · ATA ${s.aof} · unmapped ${s.unmapped} · units 1–7: ${s.vize} · units 8+: ${s.final}`);
}
console.log(`mixed_units.json: ${Object.keys(sorted).length} hashes · mapped ${mapped} · unmapped ${unmapped}`);
if (conflicts.length) console.log(`multi-unit texts: ${conflicts.length}\n  ` + conflicts.slice(0, 15).join('\n  '));
