// oys.ataaof.edu.tr export-unu (oys_export.json, oys_export_web.json) tətbiqin data fayllarına çevirir:
// data.js, config.js, testsuallari/ataaof_sorular_data.js
const fs = require('fs');
const path = require('path');

const root = __dirname;
const read = f => JSON.parse(fs.readFileSync(path.join(root, f), 'utf8'));

const dersler = read('oys_export.json').dersler;

// Variantlarında HTML teqləri olan fənn üçün xam mətndən götürülmüş export (varsa) üstünlük təşkil edir
const RAW = {};
if (fs.existsSync(path.join(root, 'oys_export_web.json'))) {
  Object.assign(RAW, read('oys_export_web.json').dersler);
}

// Saytın ünite qaytarmadığı suallar (qonşu sualların ünitesinə görə)
const UNIT_FIX = { '360727': 4, '360728': 4, '360729': 4 };

// Saytda pozuq saxlanılan suallar (soruID): 1072425-də kod sətirləri variantların yerinə düşüb, sual bərpa oluna bilmir;
// onun iki variantı isə 1081713-ün mətninin əvvəlinə yapışıb
const SKIP = new Set(['1072425']);
const Q_FIX = { '1081713': q => q.replace(/^Hata verir<br>Paragraf<br>/, '') };

// Xam exportda sual mətnindəki teqlər formatdır (<b>, <u>, <br>), variantlardakı teqlər isə cavabın özüdür (<input>, <p>)
const escapeTags = s => s.replace(/</g, '&lt;');
const tidy = s => s.replace(/\s+/g, ' ').trim();

const imgDir = path.join(root, 'img', 'oys');
let imgCount = 0;
function extractImages(html, name) {
  let n = 0;
  return html.replace(/<img[^>]*?src="data:image\/(\w+);base64,([^"]+)"[^>]*>/g, (m, ext, b64) => {
    fs.mkdirSync(imgDir, { recursive: true });
    const file = `${name}${n++ ? '_' + n : ''}.${ext === 'jpeg' ? 'jpg' : ext}`;
    fs.writeFileSync(path.join(imgDir, file), Buffer.from(b64, 'base64'));
    imgCount++;
    return `<img src="img/oys/${file}" alt="" style="max-width:100%;max-height:160px">`;
  });
}

const subjects = Object.keys(dersler);
const units = [], mixed = [], config = {}, report = [];

subjects.forEach((ad, sIdx) => {
  const isRaw = !!RAW[ad];
  const list = Object.values((isRaw ? RAW[ad] : dersler[ad]).sorular).sort((a, b) => Number(a.ssid) - Number(b.ssid));
  let skipped = 0, maxUnit = 0, count = 0;
  list.forEach(s => {
    const letters = ['A', 'B', 'C', 'D', 'E'];
    if (SKIP.has(s.soruID)) { skipped++; return; }
    let q = Q_FIX[s.soruID] ? Q_FIX[s.soruID](s.q) : s.q, o = letters.map(l => s.o[l]);
    if (isRaw) o = o.map(x => escapeTags(x || ''));
    const damaged = !isRaw && o.some(x => x === undefined || /<(?!\/?(?:strong|b|u|i|em|br|sub|sup|p|span|img)\b)|&lt;\/div/i.test(x));
    q = tidy(extractImages(q, `${s.ssid}_q`));
    o = o.map((x, i) => tidy(extractImages(x || '', `${s.ssid}_${letters[i]}`)));
    const a = letters.indexOf(s.a);
    const u = Number((s.unite && s.unite.uniteNo) || UNIT_FIX[s.ssid] || 0);
    if (damaged || !q || o.some(x => !x) || a < 0 || !u) { skipped++; return; }
    maxUnit = Math.max(maxUnit, u);
    count++;
    units.push({ c: ad, u, q, o, a });
    mixed.push({ c: 'Mixed', u: sIdx + 1, q, o, a });
  });
  config[ad] = { units: Array.from({ length: maxUnit }, (_, i) => `Unit ${i + 1}`), mixed: [], exams: [] };
  report.push(`${ad}: ${count} sual, ${maxUnit} ünite, ${skipped} buraxıldı${isRaw ? ' (xam export)' : ''}`);
});

units.sort((x, y) => subjects.indexOf(x.c) - subjects.indexOf(y.c) || x.u - y.u);

const line = q => `    { c: ${JSON.stringify(q.c)}, u: ${q.u}, q: ${JSON.stringify(q.q)}, o: ${JSON.stringify(q.o)}, a: ${q.a} },`;
fs.writeFileSync(path.join(root, 'data.js'), `const quizData = [\n${units.map(line).join('\n')}\n];\n`);
fs.writeFileSync(path.join(root, 'testsuallari', 'ataaof_sorular_data.js'), `const ataaofSorularData = [\n${mixed.map(line).join('\n')}\n];\n`);

const cfg = { Mixed: { units: subjects, mixed: [], exams: [] }, ...config };
const cfgBody = Object.entries(cfg).map(([k, v]) =>
  `    ${JSON.stringify(k)}: {\n        units: ${JSON.stringify(v.units)},\n        mixed: [],\n        exams: []\n    }`).join(',\n');
fs.writeFileSync(path.join(root, 'config.js'),
  `const CONFIG = {\n${cfgBody}\n};\n\n// Fənlərin sırası: Mixed suallarında u dəyəri bu siyahıdakı sıra nömrəsidir (1-dən başlayır)\nconst SUBJECTS = Object.keys(CONFIG).filter(c => c !== "Mixed");\n\n// İnkişaf dinamikası qrafikinin göstərdiyi dövr (ilk və son gün daxil)\nconst STUDY_PERIOD = { start: "2026-10-06", end: "2026-11-22" };\n`);

console.log(report.join('\n'));
console.log(`Cəmi ${units.length} sual, ${imgCount} şəkil`);
