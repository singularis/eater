import json
import os
from glob import glob

ROOT = os.path.dirname(os.path.dirname(__file__))
LOCALE_DIR = os.path.join(ROOT, 'Localization')

PLAN = {
    'en': 'Your Plan',
    'es': 'Tu Plan',
    'fr': 'Votre Plan',
    'de': 'Ihr Plan',
    'it': 'Il Tuo Piano',
    'pt': 'Seu Plano',
    'pl': 'Twój Plan',
    'nl': 'Uw Plan',
    'sv': 'Din Plan',
    'da': 'Din Plan',
    'fi': 'Suunnitelmasi',
    'cs': 'Váš Plán',
    'sk': 'Váš Plán',
    'sl': 'Tvoj načrt',
    'ro': 'Planul Tău',
    'bg': 'Вашият План',
    'be': 'Ваш план',
    'uk': 'Ваш План',
    'el': 'Το Πλάνο σας',
    'tr': 'Planınız',
    'ar': 'خطتك',
    'ur': 'آپ کا منصوبہ',
    'hi': 'आपकी योजना',
    'bn': 'আপনার পরিকল্পনা',
    'th': 'แผนของคุณ',
    'vi': 'Kế Hoạch Của Bạn',
    'ja': 'あなたの計画',
    'ko': '당신의 계획',
    'zh': '您的计划',
    'et': 'Sinu plaan',
    'lv': 'Tavs plāns',
    'lt': 'Jūsų planas',
    'mt': 'Il-Pjan Tiegħek',
    'ga': 'Do Phlean',
    'hr': 'Tvoj plan',
    'hu': 'Az Ön terve',
}


def update_file(path: str, code: str) -> bool:
    try:
        with open(path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception as e:
        print(f"Skip {path}: {e}")
        return False
    val = PLAN.get(code, PLAN['en'])
    # Only replace if value is in English default
    if data.get('health.plan.title') != val:
        data['health.plan.title'] = val
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
