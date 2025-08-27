import json
import os
from glob import glob

ROOT = os.path.dirname(os.path.dirname(__file__))
LOCALE_DIR = os.path.join(ROOT, 'Localization')

TRANSLATIONS = {
    'en': 'Submit Feedback',
    'es': 'Enviar comentarios',
    'fr': 'Envoyer des commentaires',
    'de': 'Feedback senden',
    'it': 'Invia feedback',
    'pt': 'Enviar feedback',
    'pl': 'Prześlij opinię',
    'nl': 'Feedback verzenden',
    'sv': 'Skicka feedback',
    'da': 'Send feedback',
    'fi': 'Lähetä palaute',
    'cs': 'Odeslat zpětnou vazbu',
    'sk': 'Odoslať spätnú väzbu',
    'sl': 'Pošlji povratne informacije',
    'ro': 'Trimite feedback',
    'bg': 'Изпрати обратна връзка',
    'be': 'Адправіць водгук',
    'uk': 'Надіслати відгук',
    'el': 'Αποστολή σχολίων',
    'tr': 'Geri bildirim gönder',
    'ar': 'إرسال ملاحظات',
    'ur': 'رائے بھیجیں',
    'hi': 'प्रतिपुष्टि भेजें',
    'bn': 'প্রতিক্রিয়া পাঠান',
    'th': 'ส่งความคิดเห็น',
    'vi': 'Gửi phản hồi',
    'ja': 'フィードバックを送信',
    'ko': '피드백 보내기',
    'zh': '提交反馈',
    'et': 'Saada tagasiside',
    'lv': 'Sūtīt atsauksmes',
    'lt': 'Siųsti atsiliepimą',
    'mt': 'Ibgħat feedback',
    'ga': 'Seol aiseolas',
    'hr': 'Pošalji povratne informacije',
    'hu': 'Visszajelzés küldése',
}


def update_file(path: str, code: str) -> bool:
    try:
        with open(path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception as e:
        print(f"Skip {path}: {e}")
        return False

    val = TRANSLATIONS.get(code, TRANSLATIONS['en'])
    if data.get('feedback.submit') != val:
        data['feedback.submit'] = val
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
