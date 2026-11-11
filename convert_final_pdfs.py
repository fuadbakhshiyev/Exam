# pdf_final/<fənn>/<dersId>-<sinavId>.pdf fayllarını (Final, Bütünləmə, Yaz Okulu / Üç Ders kitabçaları)
# testsuallari/pdf_finals_data.js faylına çevirir. Adlar pdf_final/manifest.json-dan götürülür.
# Hər kitabça yoxlanılır: sual sayı ("Bu testte N soru"), 5 variant, cavab və "CEVAP ANAHTARI" ilə uyğunluq.
# Tələb: pip install pypdf
import glob
import html
import json
import os
import re

import pypdf

from convert_pdfs import clean_text

ROOT = os.path.dirname(os.path.abspath(__file__))
SUBJECTS = [
    'Grafik Üretim Teknikleri',
    'Özgün Baskı Teknikleri',
    'Reklam Grafiği',
    'Tasarım Okumaları',
    'Web Tasarımının Temelleri',
]

def exam_id(path):
    return int(os.path.splitext(os.path.basename(path))[0].split('-')[-1])

def patched_reader(path):
    """Yeni (2025-26) kitabçalarda Calibri liqaturları (ti, tı, tt, tti…) ToUnicode-da <0000>-a
    xəritələnir və hamısı \\x00 kimi çıxır. Köhnə kitabçalarda isə həmin glif kodu birbaşa
    simvol kimi gəlir (U+019F Ɵ = ti …) və convert_pdfs.REPLACEMENTS bunları düzəldir.
    Ona görə <XXXX> <0000> qeydlərini <XXXX> <XXXX> edirik."""
    reader = pypdf.PdfReader(path)
    seen = set()
    for page in reader.pages:
        fonts = page.get('/Resources', {}).get('/Font', {})
        for ref in fonts.values():
            font = ref.get_object()
            if '/ToUnicode' not in font:
                continue
            stream = font['/ToUnicode'].get_object()
            if id(stream) in seen:
                continue
            seen.add(id(stream))
            cmap = stream.get_data().decode('latin1')
            fixed = re.sub(r'<([0-9A-Fa-f]{4})>\s*<0000>', r'<\1> <\1>', cmap)
            if fixed != cmap:
                stream.set_data(fixed.encode('latin1'))
    return reader

ANSWER_RE = re.compile(r'^(?:Doğru\s+Cevap|Cevap\s+Açıklama|Cevap)\s*:\s*\(?\s*([A-E]|[İI]ptal)\b\s*\)?', re.IGNORECASE)
KEY_RE = re.compile(r'^cevap\s+anahtar', re.IGNORECASE)

def tidy(s):
    s = ' '.join(s.replace('ﬃ', 'ffi').split())
    return re.sub(r'(?<=\S) +([.,;:?!])(?=\s|$)', r'\1', s).strip()

def parse_booklet(path):
    """Qaytarır: (suallar, gözlənilən say, ləğv edilmiş nömrələr, anahtar ilə uyğunsuzluqlar)."""
    lines = []
    for page in patched_reader(path).pages:
        pl = [clean_text(l).strip() for l in (page.extract_text() or '').split('\n')]
        pl = [l for l in pl if l]
        # Səhifə nömrələri (yalnız rəqəmdən ibarət ilk/son sətir)
        if pl and pl[0].isdigit():
            pl = pl[1:]
        if pl and pl[-1].isdigit():
            pl = pl[:-1]
        lines.extend(pl)
    text = '\n'.join(lines)
    m = re.search(r'Bu\s*testte.*?(\d+)\s+soru', text)
    expected = int(m.group(1)) if m else None

    qs, cur, state, nxt, key = [], None, None, 1, {}
    for i, line in enumerate(lines):
        if KEY_RE.match(line):
            tail = ' '.join(lines[i + 1:])
            key = {int(n): (l.upper() if len(l) == 1 else None)
                   for n, l in re.findall(r'(\d+)\s*[.\-]\s*([A-E]|[İI]ptal)\b', tail)}
            break
        qm = re.match(r'^(\d+)\s*\.\s*(.*)', line)
        if qm and int(qm.group(1)) == nxt and state in (None, 'E', 'ANS'):
            cur = {'n': nxt, 'q': qm.group(2), 'o': [], 'a': None}
            qs.append(cur)
            nxt += 1
            state = 'Q'
            continue
        if cur is None:
            continue
        am = ANSWER_RE.match(line)
        if am and state == 'E':
            v = am.group(1)
            cur['a'] = v.upper() if len(v) == 1 else 'X'
            um = re.search(r'[ÜU]nite\s*:?\s*(\d+)', line, re.IGNORECASE)
            if um:
                cur['u'] = int(um.group(1))
            state = 'ANS'
            continue
        expect_letter = 'ABCDE'[len(cur['o'])] if len(cur['o']) < 5 else None
        om = re.match(r'^([A-E])\s*\)\s*(.*)', line)
        if state in ('Q', 'A', 'B', 'C', 'D') and om and om.group(1) == expect_letter:
            cur['o'].append(om.group(2))
            state = expect_letter
            continue
        if state == 'Q':
            cur['q'] += ' ' + line
        elif state in ('A', 'B', 'C', 'D', 'E'):
            cur['o'][-1] += ' ' + line
        # 'ANS' halında izah sətirləri atılır

    out, cancelled, mismatch = [], [], []
    for q in qs:
        letter = q['a'] if q['a'] is not None else key.get(q['n'])
        if q['n'] in key and key[q['n']] is None or letter == 'X':
            cancelled.append(q['n'])
            continue
        if q['a'] not in (None, 'X') and key.get(q['n']) and key[q['n']] != q['a']:
            mismatch.append(q['n'])
        out.append({'n': q['n'], 'q': tidy(q['q']), 'o': [tidy(o) for o in q['o']],
                    'a': 'ABCDE'.index(letter) if letter else None, 'u': q.get('u')})
    return out, expected, cancelled, mismatch, len(key)

def main():
    manifest = json.load(open(os.path.join(ROOT, 'pdf_final', 'manifest.json'), encoding='utf-8'))
    names = {(m['ders'], int(m['sinavId'])): m['ad'] for m in manifest}
    data, problems = {}, []
    for subject in SUBJECTS:
        # Ən yeni imtahan birinci gəlir (sinavId böyüdükcə imtahan yenidir)
        pdfs = sorted(glob.glob(os.path.join(ROOT, 'pdf_final', subject, '*.pdf')), key=exam_id, reverse=True)
        data[subject] = []
        for pdf in pdfs:
            sid = exam_id(pdf)
            qs, expected, cancelled, mismatch, keylen = parse_booklet(pdf)
            issues = []
            total = len(qs) + len(cancelled)
            if expected is None or total != expected:
                issues.append(f'{total}/{expected} sual')
            for q in qs:
                if not q['q'] or len(q['o']) != 5 or any(not o for o in q['o']) or q['a'] is None:
                    issues.append(f"#{q['n']} natamam (atıldı)")
                if '\x00' in q['q'] + ''.join(q['o']):
                    issues.append(f"#{q['n']} oxunmayan simvol")
            if mismatch:
                issues.append('anahtar uyğunsuz: ' + ','.join(map(str, mismatch)))
            # Variantları şəkil olan suallar (mətn boşdur) atılır
            good = [q for q in qs if len(q['o']) == 5 and all(q['o']) and q['q'] and q['a'] is not None]
            # PDF mətni düz mətndir; tətbiq innerHTML ilə göstərdiyi üçün <teq> kimi variantlar qorunmalıdır
            questions = [{'q': html.escape(q['q'], quote=False),
                          'o': [html.escape(o, quote=False) for o in q['o']],
                          'a': q['a'],
                          # Kitabçada "Unite: N" yazılıbsa (bəzi illərdə var) ünitə də saxlanılır
                          **({'u': q['u']} if q['u'] else {})} for q in good]
            name = names.get((subject, sid), f'İmtahan {sid}')
            data[subject].append({'sinavId': sid, 'ad': name, 'questions': questions})
            note = f", ləğv: {cancelled}" if cancelled else ''
            status = 'OK' if not issues else 'PROBLEM: ' + '; '.join(issues)
            if issues:
                problems.append(f'{subject} {sid}: ' + '; '.join(issues))
            print(f"{subject}: {sid} ({name}) -> {len(questions)} sual, anahtar {keylen}{note} [{status}]")

    out = os.path.join(ROOT, 'testsuallari', 'pdf_finals_data.js')
    with open(out, 'w', encoding='utf-8') as f:
        f.write("// Auto-generated from pdf_final/ (convert_final_pdfs.py)\n")
        f.write("const pdfFinalsData = ")
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write(";\n")
    print(f"Cəmi {sum(len(v) for v in data.values())} imtahan, "
          f"{sum(len(e['questions']) for v in data.values() for e in v)} sual")
    print('Problemlər:', problems or 'yoxdur')

if __name__ == '__main__':
    main()
