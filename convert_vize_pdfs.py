# pdf/<fənn>/<dersId>-<sinavId>.pdf fayllarını (oys.ataaof.edu.tr keçmiş vize imtahanları)
# testsuallari/pdf_exams_data.js faylına çevirir. Tələb: pip install pypdf
import glob
import html
import json
import os

from convert_pdfs import parse_pdf

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

def main():
    data = {}
    for subject in SUBJECTS:
        # Ən yeni imtahan birinci gəlir (sinavId böyüdükcə imtahan yenidir)
        pdfs = sorted(glob.glob(os.path.join(ROOT, 'pdf', subject, '*.pdf')), key=exam_id, reverse=True)
        data[subject] = []
        for pdf in pdfs:
            qs, _ = parse_pdf(pdf, subject, {}, 1)
            # PDF mətni düz mətndir; tətbiq innerHTML ilə göstərdiyi üçün <teq> kimi variantlar qorunmalıdır
            exam = [{
                'q': html.escape(q['SoruMetni'], quote=False),
                'o': [html.escape(q[k], quote=False) for k in 'ABCDE'],
                'a': q['DogruCevapSirasi'] - 1,
            } for q in qs]
            data[subject].append(exam)
            print(f"{subject}: {os.path.basename(pdf)} -> {len(exam)} sual")

    out = os.path.join(ROOT, 'testsuallari', 'pdf_exams_data.js')
    with open(out, 'w', encoding='utf-8') as f:
        f.write("// Auto-generated from PDF files\n")
        f.write("const pdfExamsData = ")
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write(";\n")
    print(f"Cəmi {sum(len(v) for v in data.values())} imtahan, {sum(len(e) for v in data.values() for e in v)} sual")

if __name__ == '__main__':
    main()
