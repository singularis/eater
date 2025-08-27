import json
import os
from glob import glob

ROOT = os.path.dirname(os.path.dirname(__file__))
LOCALE_DIR = os.path.join(ROOT, 'Localization')

HW = {
    'en': { 'health.height': 'Height (cm):', 'health.weight': 'Weight (kg):' },
    'es': { 'health.height': 'Altura (cm):', 'health.weight': 'Peso (kg):' },
    'fr': { 'health.height': 'Taille (cm):', 'health.weight': 'Poids (kg):' },
    'de': { 'health.height': 'Größe (cm):', 'health.weight': 'Gewicht (kg):' },
    'it': { 'health.height': 'Altezza (cm):', 'health.weight': 'Peso (kg):' },
    'pt': { 'health.height': 'Altura (cm):', 'health.weight': 'Peso (kg):' },
    'pl': { 'health.height': 'Wzrost (cm):', 'health.weight': 'Waga (kg):' },
    'nl': { 'health.height': 'Lengte (cm):', 'health.weight': 'Gewicht (kg):' },
    'sv': { 'health.height': 'Längd (cm):', 'health.weight': 'Vikt (kg):' },
    'da': { 'health.height': 'Højde (cm):', 'health.weight': 'Vægt (kg):' },
    'fi': { 'health.height': 'Pituus (cm):', 'health.weight': 'Paino (kg):' },
    'cs': { 'health.height': 'Výška (cm):', 'health.weight': 'Hmotnost (kg):' },
    'sk': { 'health.height': 'Výška (cm):', 'health.weight': 'Hmotnosť (kg):' },
    'sl': { 'health.height': 'Višina (cm):', 'health.weight': 'Teža (kg):' },
    'ro': { 'health.height': 'Înălțime (cm):', 'health.weight': 'Greutate (kg):' },
    'bg': { 'health.height': 'Ръст (см):', 'health.weight': 'Тегло (кг):' },
    'be': { 'health.height': 'Рост (см):', 'health.weight': 'Вага (кг):' },
    'uk': { 'health.height': 'Зріст (см):', 'health.weight': 'Вага (кг):' },
    'el': { 'health.height': 'Ύψος (cm):', 'health.weight': 'Βάρος (kg):' },
    'tr': { 'health.height': 'Boy (cm):', 'health.weight': 'Kilo (kg):' },
    'ar': { 'health.height': 'الطول (سم):', 'health.weight': 'الوزن (كغ):' },
    'ur': { 'health.height': 'قد (سم):', 'health.weight': 'وزن (کلو):' },
    'hi': { 'health.height': 'ऊँचाई (सेमी):', 'health.weight': 'वजन (कि.ग्रा.):' },
    'bn': { 'health.height': 'উচ্চতা (সেমি):', 'health.weight': 'ওজন (কেজি):' },
    'th': { 'health.height': 'ส่วนสูง (ซม.):', 'health.weight': 'น้ำหนัก (กก.):' },
    'vi': { 'health.height': 'Chiều cao (cm):', 'health.weight': 'Cân nặng (kg):' },
    'ja': { 'health.height': '身長 (cm):', 'health.weight': '体重 (kg):' },
    'ko': { 'health.height': '키 (cm):', 'health.weight': '몸무게 (kg):' },
    'zh': { 'health.height': '身高 (厘米):', 'health.weight': '体重 (千克):' },
    'et': { 'health.height': 'Pikkus (cm):', 'health.weight': 'Kaal (kg):' },
    'lv': { 'health.height': 'Augums (cm):', 'health.weight': 'Svars (kg):' },
    'lt': { 'health.height': 'Ūgis (cm):', 'health.weight': 'Svoris (kg):' },
    'mt': { 'health.height': 'Għoli (cm):', 'health.weight': 'Piż (kg):' },
    'ga': { 'health.height': 'Airde (cm):', 'health.weight': 'Meáchan (kg):' },
    'hr': { 'health.height': 'Visina (cm):', 'health.weight': 'Težina (kg):' },
    'hu': { 'health.height': 'Magasság (cm):', 'health.weight': 'Testsúly (kg):' },
}


def update_file(path: str, code: str) -> bool:
    try:
        with open(path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception as e:
        print(f"Skip {path}: {e}")
        return False
    trans = HW.get(code, HW['en'])
    changed = False
    for k, v in trans.items():
        if data.get(k) != v:
            data[k] = v
            changed = True
    if changed:
        data_sorted = {k: data[k] for k in sorted(data.keys())}
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(data_sorted, f, ensure_ascii=False, indent=2)
    return changed


def main():
    files = sorted(glob(os.path.join(LOCALE_DIR, '*.json')))
    changed = 0
    for p in files:
        base = os.path.basename(p)
        if base.lower() == 'contents.json':
            continue
        code = base.split('.')[0]
        if update_file(p, code):
            print(f"Updated: {base}")
            changed += 1
    print(f"Done. Updated {changed}/{len(files)} files.")

if __name__ == '__main__':
    main()
