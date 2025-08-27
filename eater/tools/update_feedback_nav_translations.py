import json
import os
from glob import glob

ROOT = os.path.dirname(os.path.dirname(__file__))
LOCALE_DIR = os.path.join(ROOT, 'Localization')

NAV = {
    'en': 'Feedback',
    'es': 'Comentarios',
    'fr': 'Retour',
    'de': 'Feedback',
    'it': 'Feedback',
    'pt': 'Feedback',
    'pl': 'Opinie',
    'nl': 'Feedback',
    'sv': 'Feedback',
    'da': 'Feedback',
    'fi': 'Palaute',
    'cs': 'Zpětná vazba',
    'sk': 'Spätná väzba',
    'sl': 'Povratne informacije',
    'ro': 'Feedback',
    'bg': 'Обратна връзка',
    'be': 'Зваротная сувязь',
    'uk': 'Відгук',
    'el': 'Σχόλια',
    'tr': 'Geri bildirim',
    'ar': 'ملاحظات',
    'ur': 'رائے',
    'hi': 'प्रतिपुष्टि',
    'bn': 'প্রতিক্রিয়া',
    'th': 'ข้อเสนอแนะ',
    'vi': 'Phản hồi',
    'ja': 'フィードバック',
    'ko': '피드백',
    'zh': '反馈',
    'et': 'Tagasiside',
    'lv': 'Atsauksmes',
    'lt': 'Atsiliepimai',
    'mt': 'Feedback',
    'ga': 'Aiseolas',
    'hr': 'Povratne informacije',
    'hu': 'Visszajelzés',
}


def update_file(path: str, code: str) -> bool:
    try:
        with open(path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception as e:
        print(f"Skip {path}: {e}")
        return False
    val = NAV.get(code, NAV['en'])
    if data.get('feedback.nav') != val:
        data['feedback.nav'] = val
        data_sorted = {k: data[k] for k in sorted(data.keys())}
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
