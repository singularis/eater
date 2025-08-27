import json
import os
from glob import glob

ROOT = os.path.dirname(os.path.dirname(__file__))
LOCALE_DIR = os.path.join(ROOT, 'Localization')

DATE_TODAY = {
    'en': "Today",
    'es': "Hoy",
    'fr': "Aujourd'hui",
    'de': "Heute",
    'it': "Oggi",
    'pt': "Hoje",
    'pl': "Dziś",
    'nl': "Vandaag",
    'sv': "Idag",
    'da': "I dag",
    'fi': "Tänään",
    'cs': "Dnes",
    'sk': "Dnes",
    'sl': "Danes",
    'ro': "Astăzi",
    'bg': "Днес",
    'be': "Сёння",
    'uk': "Сьогодні",
    'el': "Σήμερα",
    'tr': "Bugün",
    'ar': "اليوم",
    'ur': "آج",
    'hi': "आज",
    'bn': "আজ",
    'th': "วันนี้",
    'vi': "Hôm nay",
    'ja': "今日",
    'ko': "오늘",
    'zh': "今天",
    'et': "Täna",
    'lv': "Šodien",
    'lt': "Šiandien",
    'mt': "Illum",
    'ga': "Inniu",
    'hr': "Danas",
    'hu': "Ma",
}

DATE_CUSTOM = {
    'en': "Custom Date",
    'es': "Fecha personalizada",
    'fr': "Date personnalisée",
    'de': "Benutzerdefiniertes Datum",
    'it': "Data personalizzata",
    'pt': "Data personalizada",
    'pl': "Niestandardowa data",
    'nl': "Aangepaste datum",
    'sv': "Anpassat datum",
    'da': "Brugerdefineret dato",
    'fi': "Mukautettu päivämäärä",
    'cs': "Vlastní datum",
    'sk': "Vlastný dátum",
    'sl': "Datum po meri",
    'ro': "Dată personalizată",
    'bg': "Персонализирана дата",
    'be': "Індывідуальная дата",
    'uk': "Власна дата",
    'el': "Προσαρμοσμένη ημερομηνία",
    'tr': "Özel tarih",
    'ar': "تاريخ مخصص",
    'ur': "حسبِ مرضی تاریخ",
    'hi': "कस्टम तिथि",
    'bn': "কাস্টম তারিখ",
    'th': "วันที่กำหนดเอง",
    'vi': "Ngày tùy chỉnh",
    'ja': "カスタム日付",
    'ko': "사용자 지정 날짜",
    'zh': "自定义日期",
    'et': "Kohandatud kuupäev",
    'lv': "Pielāgots datums",
    'lt': "Tinkinta data",
    'mt': "Data personalizzata",
    'ga': "Dáta saincheaptha",
    'hr': "Prilagođeni datum",
    'hu': "Egyéni dátum",
}


def update_file(path: str, code: str) -> bool:
    try:
        with open(path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception as e:
        print(f"Skip {path}: {e}")
        return False

    changed = False
    today_val = DATE_TODAY.get(code, DATE_TODAY['en'])
    custom_val = DATE_CUSTOM.get(code, DATE_CUSTOM['en'])
    if data.get('date.today') != today_val:
        data['date.today'] = today_val
        changed = True
    if data.get('date.custom') != custom_val:
        data['date.custom'] = custom_val
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
