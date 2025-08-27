import json
import os
from glob import glob

ROOT = os.path.dirname(os.path.dirname(__file__))
LOCALE_DIR = os.path.join(ROOT, 'Localization')

MAP = {
    'en': '%@/day',
    'es': '%@/día',
    'fr': '%@/jour',
    'de': '%@/Tag',
    'it': '%@/giorno',
    'pt': '%@/dia',
    'pl': '%@/dzień',
    'nl': '%@/dag',
    'sv': '%@/dag',
    'da': '%@/dag',
    'fi': '%@/päivä',
    'cs': '%@/den',
    'sk': '%@/deň',
    'sl': '%@/dan',
    'ro': '%@/zi',
    'bg': '%@/ден',
    'be': '%@/дзень',
    'uk': '%@/день',
    'el': '%@/ημέρα',
    'tr': '%@/gün',
    'ar': '%@/اليوم',
    'ur': '%@/دن',
    'hi': '%@/दिन',
    'bn': '%@/দিন',
    'th': '%@/วัน',
    'vi': '%@/ngày',
    'ja': '%@/日',
    'ko': '%@/일',
    'zh': '%@/天',
    'et': '%@/päevas',
    'lv': '%@/dienā',
    'lt': '%@/dieną',
    'mt': '%@/ġurnata',
    'ga': '%@/lá',
    'hr': '%@/dan',
    'hu': '%@/nap',
}


def update_file(path: str, code: str) -> bool:
    try:
        with open(path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception as e:
        print(f"Skip {path}: {e}")
        return False
    new_val = MAP.get(code, '%@/day')
    if data.get('units.per_day_format') != new_val:
        data['units.per_day_format'] = new_val
        data_sorted = {k: data[k] for k in sorted(data)}
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(data_sorted, f, ensure_ascii=False, indent=2)
        return True
    return False


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
