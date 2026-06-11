import os
import pypdf
import re
import json
import unicodedata

# Mapping from normalized folder names to standard subject names and indices
FOLDER_TO_SUBJECT = {
    'ataturkilkeleri': 'Atatürk İlkeleri ve İnkılap Tarihi II',
    'grafiktasarim': 'Grafik Tasarım II',
    'grafiktasarım': 'Grafik Tasarım II',
    'gorseliletisim': 'Görsel İletişim Tasarımı',
    'masaustuyayincilik': 'Masaüstü Yayıncılık',
    'tasarimdatipografi': 'Tasarımda Tipografi',
    'turkdili': 'Türk Dili II'
}

# Unicode replacements for PDF ligature corrections
REPLACEMENTS = {
    'Ɵ': 'ti',
    'ƨ': 'tı',
    'ﬁ': 'fi',
    'ﬂ': 'fl',
    'ƫ': 'tti',
    'ķ': 'fı',
    'Ō': 'ft',
    'Ʃ': 'tt',
    'ƴ': 'tı',
    'Ņ': 't',
    'ƞ': 'tf',
    'ﬀ': 'ff',
}

def clean_text(text):
    if not text:
        return ""
    # Normalize unicode characters to NFC
    text = unicodedata.normalize('NFC', text)
    # Apply corrections
    for k, v in REPLACEMENTS.items():
        text = text.replace(k, v)
    # Replace non-breaking spaces with normal spaces
    text = text.replace('\u00A0', ' ')
    return text

def normalize_for_lookup(text):
    if not text:
        return ""
    # Remove HTML tags
    text = re.sub(r'<[^>]+>', '', text)
    # Clean whitespace
    text = ' '.join(text.split())
    # Keep alphanumeric characters in lowercase
    text = re.sub(r'[^a-z0-9ıışşğğööççüüğğİİ]', '', text.lower())
    return text[:60] # match based on first 60 characters for robustness

def extract_unit_from_explanation(text):
    if not text:
        return None
    match = re.search(r'(?i)\b(?:ünite|unite|bölüm|bolum|unit)\b[:\s]*(\d+)', text)
    if match:
        return int(match.group(1))
    return None

def build_unit_lookup():
    lookup = {}
    
    # 1. Try to load from ataaof_sorular.json if it exists
    json_path = '/Users/fuad/Desktop/Projects/Imtahan/testsuallari/ataaof_sorular.json'
    if os.path.exists(json_path):
        try:
            with open(json_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
            for subject, s_data in data.get('dersler', {}).items():
                for q in s_data.get('sorular', []):
                    norm = normalize_for_lookup(q.get('SoruMetni', ''))
                    if norm and 'Unite' in q:
                        lookup[norm] = q['Unite']
        except Exception as e:
            print(f"Warning: Could not build lookup from JSON: {e}")
            
    # 2. Try to load from data.js if it exists
    data_js_path = '/Users/fuad/Desktop/Projects/Imtahan/data.js'
    if os.path.exists(data_js_path):
        try:
            with open(data_js_path, 'r', encoding='utf-8') as f:
                content = f.read()
            lines = content.split('\n')
            for line in lines:
                u_match = re.search(r'\bu:\s*(\d+)', line)
                q_match = re.search(r'\bq:\s*"([^"]*)"', line) or re.search(r"\bq:\s*'([^']*)'", line)
                if u_match and q_match:
                    norm = normalize_for_lookup(q_match.group(1))
                    if norm:
                        lookup[norm] = int(u_match.group(1))
        except Exception as e:
            print(f"Warning: Could not build lookup from data.js: {e}")
            
    print(f"Built unit lookup table with {len(lookup)} unique questions.")
    return lookup

def parse_pdf(pdf_path, subject_name, unit_lookup, next_id):
    reader = pypdf.PdfReader(pdf_path)
    lines = []
    for page in reader.pages:
        txt = page.extract_text()
        if txt:
            lines.extend(txt.split('\n'))
            
    # Clean lines
    lines = [clean_text(line).strip() for line in lines]
    
    questions = []
    current_q = None
    expected_num = 1
    state = 'LOOKING_FOR_Q'
    
    for line in lines:
        if not line:
            continue
            
        # Check for start of a new question
        q_start_match = re.match(r'^(\d+)\.\s*(.*)', line)
        if q_start_match:
            num = int(q_start_match.group(1))
            if num == expected_num:
                # Save previous question if complete
                if current_q and current_q['DogruCevap'] is not None:
                    questions.append(current_q)
                
                current_q = {
                    'SoruID': next_id,
                    'SoruMetni': q_start_match.group(2).strip(),
                    'options': ['', '', '', '', ''],
                    'DogruCevap': None,
                    'DogruCevapSirasi': None,
                    'Unite': 1, # default
                    'DersAd': subject_name,
                    'explanation': ''
                }
                next_id += 1
                expected_num += 1
                state = 'Q_TEXT'
                continue
                
        if not current_q:
            continue
            
        if state == 'Q_TEXT':
            opt_match = re.match(r'^A\s*[\)\.\u00A0]\s*(.*)', line)
            if opt_match:
                current_q['options'][0] = opt_match.group(1).strip()
                state = 'OPT_A'
            else:
                current_q['SoruMetni'] += ' ' + line
                
        elif state == 'OPT_A':
            opt_match = re.match(r'^B\s*[\)\.\u00A0]\s*(.*)', line)
            if opt_match:
                current_q['options'][1] = opt_match.group(1).strip()
                state = 'OPT_B'
            else:
                current_q['options'][0] += ' ' + line
                
        elif state == 'OPT_B':
            opt_match = re.match(r'^C\s*[\)\.\u00A0]\s*(.*)', line)
            if opt_match:
                current_q['options'][2] = opt_match.group(1).strip()
                state = 'OPT_C'
            else:
                current_q['options'][1] += ' ' + line
                
        elif state == 'OPT_C':
            opt_match = re.match(r'^D\s*[\)\.\u00A0]\s*(.*)', line)
            if opt_match:
                current_q['options'][3] = opt_match.group(1).strip()
                state = 'OPT_D'
            else:
                current_q['options'][2] += ' ' + line
                
        elif state == 'OPT_D':
            opt_match = re.match(r'^E\s*[\)\.\u00A0]\s*(.*)', line)
            if opt_match:
                current_q['options'][4] = opt_match.group(1).strip()
                state = 'OPT_E'
            else:
                current_q['options'][3] += ' ' + line
                
        elif state == 'OPT_E':
            ans_match = re.match(r'^(?:Cevap\s+Açıklama\s*:\s*|Doğru\s+Cevap\s*:\s*|Cevap\s*:\s*)\(?\s*([A-E])\s*\)?(.*)', line, re.IGNORECASE)
            if ans_match:
                ans_letter = ans_match.group(1).upper()
                current_q['DogruCevap'] = ans_letter
                current_q['DogruCevapSirasi'] = ord(ans_letter) - ord('A') + 1
                current_q['explanation'] = ans_match.group(2).strip()
                state = 'ANSWER'
            else:
                current_q['options'][4] += ' ' + line
                
        elif state == 'ANSWER':
            current_q['explanation'] += ' ' + line
            
    # Append the last question
    if current_q and current_q['DogruCevap'] is not None:
        questions.append(current_q)
        
    # Final cleanup of whitespaces and resolving units
    for q in questions:
        q['SoruMetni'] = ' '.join(q['SoruMetni'].split()).strip()
        for i in range(5):
            q['options'][i] = ' '.join(q['options'][i].split()).strip()
            
        # Map options back to A, B, C, D, E fields
        q['A'] = q['options'][0]
        q['B'] = q['options'][1]
        q['C'] = q['options'][2]
        q['D'] = q['options'][3]
        q['E'] = q['options'][4]
        del q['options']
        
        # Resolve unit
        unit_extracted = extract_unit_from_explanation(q['explanation'])
        if unit_extracted is not None:
            q['Unite'] = unit_extracted
        else:
            norm = normalize_for_lookup(q['SoruMetni'])
            if norm in unit_lookup:
                q['Unite'] = unit_lookup[norm]
            else:
                q['Unite'] = 1 # fallback
                
        del q['explanation'] # remove explanation as it is not needed in the quiz JSON database
        
    return questions, next_id

def main():
    pdf_dir = '/Users/fuad/Desktop/Projects/Imtahan/pdf'
    unit_lookup = build_unit_lookup()
    
    # Track the maximum SoruID in existing ataaof_sorular.json to avoid collision
    json_path = '/Users/fuad/Desktop/Projects/Imtahan/testsuallari/ataaof_sorular.json'
    existing_questions_lookup = set()
    existing_db = None
    next_id = 300000
    
    if os.path.exists(json_path):
        try:
            with open(json_path, 'r', encoding='utf-8') as f:
                existing_db = json.load(f)
            
            # Find max ID
            max_id = 0
            for subject, s_data in existing_db.get('dersler', {}).items():
                for q in s_data.get('sorular', []):
                    max_id = max(max_id, q.get('SoruID', 0))
                    # Record for deduplication
                    norm = normalize_for_lookup(q.get('SoruMetni', ''))
                    if norm:
                        existing_questions_lookup.add(norm)
            
            if max_id > 0:
                next_id = max_id + 1
            print(f"Loaded existing database. Max SoruID: {max_id}. Next ID will start from {next_id}.")
        except Exception as e:
            print(f"Error loading existing JSON: {e}")
            
    if not existing_db:
        # Create empty db structure if it didn't exist
        existing_db = {
            "kaynak": "converted_pdfs",
            "kaynak_yolu": pdf_dir,
            "olusturulma_tarihi": "2026-06-11 16:30:00",
            "toplam_soru": 0,
            "ders_sayisi": 6,
            "dersler": {}
        }
        
    total_parsed_files = 0
    total_parsed_questions = 0
    total_added_questions = 0
    
    # Process each subdirectory
    for folder in sorted(os.listdir(pdf_dir)):
        folder_path = os.path.join(pdf_dir, folder)
        if not os.path.isdir(folder_path):
            continue
            
        # Normalize folder name to match our subjects
        norm_folder = normalize_for_lookup(folder)
        if norm_folder not in FOLDER_TO_SUBJECT:
            print(f"Warning: Skipping folder {folder} (does not match any standard subject).")
            continue
            
        subject_name = FOLDER_TO_SUBJECT[norm_folder]
        print(f"\nProcessing folder: {folder} -> Subject: {subject_name}")
        
        # Prepare sub-db structure if needed
        if subject_name not in existing_db['dersler']:
            existing_db['dersler'][subject_name] = {
                "soru_sayisi": 0,
                "sorular": []
            }
            
        # Find all PDFs in this directory
        pdfs = sorted([f for f in os.listdir(folder_path) if f.endswith('.pdf')])
        
        for pdf in pdfs:
            pdf_path = os.path.join(folder_path, pdf)
            try:
                qs, next_id = parse_pdf(pdf_path, subject_name, unit_lookup, next_id)
                total_parsed_files += 1
                total_parsed_questions += len(qs)
                
                # Save individual JSON file
                json_output_path = os.path.splitext(pdf_path)[0] + '.json'
                with open(json_output_path, 'w', encoding='utf-8') as jf:
                    json.dump(qs, jf, ensure_ascii=False, indent=2)
                
                # Merge into central DB (with deduplication)
                added_for_file = 0
                for q in qs:
                    norm = normalize_for_lookup(q['SoruMetni'])
                    if norm not in existing_questions_lookup:
                        existing_questions_lookup.add(norm)
                        existing_db['dersler'][subject_name]['sorular'].append(q)
                        added_for_file += 1
                        total_added_questions += 1
                
                print(f"  Parsed {pdf}: {len(qs)} questions (Added {added_for_file} new, {len(qs) - added_for_file} duplicates).")
            except Exception as e:
                print(f"  Error parsing {pdf}: {e}")
                
    # Update totals in consolidated DB
    global_total = 0
    for subject, s_data in existing_db['dersler'].items():
        s_data['soru_sayisi'] = len(s_data['sorular'])
        global_total += s_data['soru_sayisi']
    existing_db['toplam_soru'] = global_total
    
    # Save the updated central JSON database
    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(existing_db, f, ensure_ascii=False, indent=2)
        
    # Compile static pdf_exams_data.js for high-performance offline access in UI
    exams_js_data = {}
    for folder in sorted(os.listdir(pdf_dir)):
        folder_path = os.path.join(pdf_dir, folder)
        if not os.path.isdir(folder_path):
            continue
            
        norm_folder = normalize_for_lookup(folder)
        if norm_folder not in FOLDER_TO_SUBJECT:
            continue
            
        subject_name = FOLDER_TO_SUBJECT[norm_folder]
        exams_js_data[subject_name] = []
        
        # Find all PDFs in this directory
        pdfs = sorted([f for f in os.listdir(folder_path) if f.endswith('.pdf')])
        for pdf in pdfs:
            pdf_path = os.path.join(folder_path, pdf)
            json_path_individual = os.path.splitext(pdf_path)[0] + '.json'
            if os.path.exists(json_path_individual):
                try:
                    with open(json_path_individual, 'r', encoding='utf-8') as jf:
                        qs = json.load(jf)
                    # Convert to simplified format for JS: { q, o, a }
                    simplified_qs = []
                    for q in qs:
                        simplified_qs.append({
                            'q': q['SoruMetni'],
                            'o': [q['A'], q['B'], q['C'], q['D'], q['E']],
                            'a': q['DogruCevapSirasi'] - 1
                        })
                    if simplified_qs:
                        exams_js_data[subject_name].append(simplified_qs)
                except Exception as e:
                    print(f"Error compiling JS for {pdf}: {e}")
                    
    # Write to pdf_exams_data.js
    js_output_path = '/Users/fuad/Desktop/Projects/Imtahan/testsuallari/pdf_exams_data.js'
    with open(js_output_path, 'w', encoding='utf-8') as f:
        f.write("// Auto-generated from PDF files\n")
        f.write("const pdfExamsData = ")
        json.dump(exams_js_data, f, ensure_ascii=False, indent=2)
        f.write(";\n")
        
    print("\n" + "="*50)
    print("CONVERSION SUMMARY:")
    print(f"Total PDF files successfully parsed: {total_parsed_files}")
    print(f"Total questions parsed from PDFs: {total_parsed_questions}")
    print(f"Total new unique questions added to database: {total_added_questions}")
    print(f"New global total questions in ataaof_sorular.json: {global_total}")
    print(f"Compiled pdf_exams_data.js with {sum(len(v) for v in exams_js_data.values())} exams.")
    print("="*50)

if __name__ == '__main__':
    main()
