import json
import os
from glob import glob

ROOT = os.path.dirname(os.path.dirname(__file__))
LOCALE_DIR = os.path.join(ROOT, 'Localization')

KG = {
    'en': 'kg', 'es': 'kg', 'fr': 'kg', 'de': 'kg', 'it': 'kg', 'pt': 'kg', 'nl': 'kg',
    'sv': 'kg', 'da': 'kg', 'fi': 'kg', 'cs': 'kg', 'sk': 'kg', 'sl': 'kg', 'ro': 'kg',
    'pl': 'kg', 'et': 'kg', 'lv': 'kg', 'lt': 'kg', 'mt': 'kg', 'ga': 'kg', 'hr': 'kg', 'hu': 'kg',
    'el': 'kg',  # Greek commonly uses Latin symbol
    'tr': 'kg', 'vi': 'kg', 'ko': 'kg',
    'ja': 'kg',  # symbol commonly stays Latin
    'zh': '千克',
    'th': 'กก.',
    'ar': 'كغ',
    'ur': 'کلو',
    'hi': 'कि.ग्रा.',
    'bn': 'কেজি',
    'uk': 'кг',
    'bg': 'кг',
    'be': 'кг',
}

KCAL = {
    'en': 'kcal', 'es': 'kcal', 'fr': 'kcal', 'de': 'kcal', 'it': 'kcal', 'pt': 'kcal', 'nl': 'kcal',
    'sv': 'kcal', 'da': 'kcal', 'fi': 'kcal', 'cs': 'kcal', 'sk': 'kcal', 'sl': 'kcal', 'ro': 'kcal',
    'pl': 'kcal', 'et': 'kcal', 'lv': 'kcal', 'lt': 'kcal', 'mt': 'kcal', 'ga': 'kcal', 'hr': 'kcal', 'hu': 'kcal',
    'el': 'kcal',  # Greek usually uses kcal
    'tr': 'kcal', 'vi': 'kcal', 'ko': 'kcal',
    'ja': 'キロカロリー',
    'zh': '千卡',
    'th': 'กิโลแคลอรี',
    'ar': 'كيلوكالوري',
    'ur': 'کيلوکیلوری',
    'hi': 'किलो कैलोरी',
    'bn': 'কিলোক্যালোরি',
    'uk': 'ккал',
    'bg': 'ккал',
    'be': 'ккал',
}


def update_file(path: str, code: str) -> bool:
    try:
        with open(path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception as e:
        print(f"Skip {path}: {e}")
        return False

    kg_val = KG.get(code, 'kg')
    kcal_val = KCAL.get(code, 'kcal')
    changed = False
    if data.get('units.kg') != kg_val:
        data['units.kg'] = kg_val
        changed = True
    if data.get('units.kcal') != kcal_val:
        data['units.kcal'] = kcal_val
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
