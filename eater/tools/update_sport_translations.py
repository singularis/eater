import json
import os
from glob import glob

ROOT = os.path.dirname(os.path.dirname(__file__))
LOCALE_DIR = os.path.join(ROOT, 'Localization')

SPORT = {
    'en': {
        'sport.title': 'Sport Calories Bonus',
        'sport.placeholder': 'Calories burned (e.g., 300)',
        'sport.add': "Add to Today's Limit",
        'sport.msg': 'Enter the number of calories you burned during your workout. This will be added to your daily calorie limit for today only.'
    },
    'es': {
        'sport.title': 'Bonificación de calorías de ejercicio',
        'sport.placeholder': 'Calorías quemadas (p. ej., 300)',
        'sport.add': 'Agregar al límite de hoy',
        'sport.msg': 'Introduce el número de calorías que quemaste durante tu entrenamiento. Se añadirá a tu límite calórico diario solo por hoy.'
    },
    'fr': {
        'sport.title': "Bonus de calories d’activité",
        'sport.placeholder': 'Calories brûlées (ex. 300)',
        'sport.add': 'Ajouter à la limite d’aujourd’hui',
        'sport.msg': 'Saisissez le nombre de calories brûlées pendant votre entraînement. Ce total sera ajouté à votre limite quotidienne pour aujourd’hui uniquement.'
    },
    'de': {
        'sport.title': 'Sport-Kalorienbonus',
        'sport.placeholder': 'Verbrannte Kalorien (z. B. 300)',
        'sport.add': 'Zur heutigen Grenze hinzufügen',
        'sport.msg': 'Geben Sie die während des Trainings verbrannten Kalorien ein. Sie werden nur für heute zu Ihrem Tageslimit hinzugefügt.'
    },
    'it': {
        'sport.title': 'Bonus calorie attività',
        'sport.placeholder': 'Calorie bruciate (es. 300)',
        'sport.add': 'Aggiungi al limite di oggi',
        'sport.msg': 
            "Inserisci il numero di calorie bruciate durante l'allenamento. Verranno aggiunte al limite calorico giornaliero solo per oggi."
    },
    'pt': {
        'sport.title': 'Bônus de calorias de exercício',
        'sport.placeholder': 'Calorias queimadas (ex.: 300)',
        'sport.add': 'Adicionar ao limite de hoje',
        'sport.msg': 'Informe o número de calorias queimadas no treino. Será adicionado ao seu limite diário apenas hoje.'
    },
    'pl': {
        'sport.title': 'Premia kalorii za ćwiczenia',
        'sport.placeholder': 'Spalone kalorie (np. 300)',
        'sport.add': 'Dodaj do dzisiejszego limitu',
        'sport.msg': 'Wpisz liczbę kalorii spalonych podczas treningu. Zostaną dodane do dziennego limitu tylko na dziś.'
    },
    'nl': {
        'sport.title': 'Sportcaloriebonus',
        'sport.placeholder': 'Verbrande calorieën (bijv. 300)',
        'sport.add': 'Toevoegen aan limiet van vandaag',
        'sport.msg': 'Voer het aantal verbrande calorieën tijdens je training in. Dit wordt alleen vandaag bij je daglimiet opgeteld.'
    },
    'sv': {
        'sport.title': 'Bonus för sportkalorier',
        'sport.placeholder': 'Förbrända kalorier (t.ex. 300)',
        'sport.add': 'Lägg till dagens gräns',
        'sport.msg': 'Ange hur många kalorier du förbrände under passet. Det läggs till din dagliga gräns endast idag.'
    },
    'da': {
        'sport.title': 'Bonus for sportkalorier',
        'sport.placeholder': 'Forbrændte kalorier (f.eks. 300)',
        'sport.add': 'Føj til dagens grænse',
        'sport.msg': 'Indtast antallet af kalorier, du forbrændte under træningen. Det lægges til din daglige grænse kun i dag.'
    },
    'fi': {
        'sport.title': 'Liikuntakalorien bonus',
        'sport.placeholder': 'Kulutetut kalorit (esim. 300)',
        'sport.add': 'Lisää tämän päivän rajaan',
        'sport.msg': 'Syötä harjoituksessa kulutetut kalorit. Ne lisätään tämän päivän päivärajaan.'
    },
    'cs': {
        'sport.title': 'Bonus sportovních kalorií',
        'sport.placeholder': 'Spálené kalorie (např. 300)',
        'sport.add': 'Přidat k dnešnímu limitu',
        'sport.msg': 'Zadejte počet kalorií spálených při tréninku. Přičtou se pouze k dnešnímu dennímu limitu.'
    },
    'sk': {
        'sport.title': 'Bonus športových kalórií',
        'sport.placeholder': 'Spálené kalórie (napr. 300)',
        'sport.add': 'Pridať k dnešnému limitu',
        'sport.msg': 'Zadajte počet kalórií spálených počas tréningu. Pripočítajú sa len k dnešnému dennému limitu.'
    },
    'sl': {
        'sport.title': 'Bonus športnih kalorij',
        'sport.placeholder': 'Porabljene kalorije (npr. 300)',
        'sport.add': 'Dodaj današnji meji',
        'sport.msg': 'Vnesite število kalorij, porabljenih med vadbo. Prištete bodo le današnji dnevni omejitvi.'
    },
    'ro': {
        'sport.title': 'Bonus calorii sport',
        'sport.placeholder': 'Calorii arse (ex.: 300)',
        'sport.add': 'Adaugă la limita de azi',
        'sport.msg': 'Introduceți numărul de calorii arse în timpul antrenamentului. Vor fi adăugate la limita zilnică doar pentru azi.'
    },
    'bg': {
        'sport.title': 'Бонус спортни калории',
        'sport.placeholder': 'Изгорени калории (напр. 300)',
        'sport.add': 'Добави към днешния лимит',
        'sport.msg': 'Въведете калориите, изгорени по време на тренировка. Те ще се добавят към дневния лимит само за днес.'
    },
    'be': {
        'sport.title': 'Бонус спартовых калорый',
        'sport.placeholder': 'Спаленыя калорыі (напрыклад, 300)',
        'sport.add': 'Дадаць да сённяшняга ліміту',
        'sport.msg': 'Увядзіце колькасць калорый, спаленых падчас трэніроўкі. Яны будуць дададзены толькі да сённяшняга дзённага ліміту.'
    },
    'uk': {
        'sport.title': 'Бонус спортивних калорій',
        'sport.placeholder': 'Спалені калорії (напр., 300)',
        'sport.add': 'Додати до сьогоднішнього ліміту',
        'sport.msg': 'Введіть кількість калорій, спалених під час тренування. Їх буде додано до вашого денного ліміту лише на сьогодні.'
    },
    'el': {
        'sport.title': 'Μπόνους θερμίδων άσκησης',
        'sport.placeholder': 'Θερμίδες που κάηκαν (π.χ. 300)',
        'sport.add': 'Προσθήκη στο σημερινό όριο',
        'sport.msg': 'Εισαγάγετε τις θερμίδες που κάψατε κατά την προπόνηση. Θα προστεθούν στο ημερήσιο όριο μόνο για σήμερα.'
    },
    'tr': {
        'sport.title': 'Egzersiz kalorisi bonusu',
        'sport.placeholder': 'Yakılan kalori (ör. 300)',
        'sport.add': 'Bugünkü sınıra ekle',
        'sport.msg': 'Antrenmanda yaktığınız kalori miktarını girin. Yalnızca bugünlük günlük sınırınıza eklenecektir.'
    },
    'ar': {
        'sport.title': 'مكافأة سعرات الرياضة',
        'sport.placeholder': 'السعرات المحروقة (مثلاً 300)',
        'sport.add': 'أضِف إلى حد اليوم',
        'sport.msg': 'أدخل عدد السعرات التي حرقتها أثناء التمرين. ستُضاف إلى حدك اليومي لليوم فقط.'
    },
    'ur': {
        'sport.title': 'کھیل کیلوری بونس',
        'sport.placeholder': 'جلنے والی کیلوریز (مثلاً 300)',
        'sport.add': 'آج کی حد میں شامل کریں',
        'sport.msg': 'ورزش کے دوران جلنے والی کیلوریز درج کریں۔ یہ صرف آج کے لیے آپ کی روزانہ حد میں شامل ہوں گی.'
    },
    'hi': {
        'sport.title': 'व्यायाम कैलोरी बोनस',
        'sport.placeholder': 'जली कैलोرी (जैसे, 300)',
        'sport.add': 'आज की सीमा में जोड़ें',
        'sport.msg': 'वर्कआउट के दौरान जली हुई कैलोरी दर्ज करें। यह केवल आज के लिए आपकी दैनिक सीमा में जोड़ दी जाएगी.'
    },
    'bn': {
        'sport.title': 'ব্যায়ামের ক্যালোরি বোনাস',
        'sport.placeholder': 'পোড়া ক্যালোরি (যেমন, ৩০০)',
        'sport.add': 'আজকের সীমায় যোগ করুন',
        'sport.msg': 'ব্যায়ামের সময় পোড়া ক্যালোরির সংখ্যা লিখুন। এটি শুধু আজকের জন্য আপনার দৈনিক সীমায় যোগ হবে.'
    },
    'th': {
        'sport.title': 'โบนัสแคลอรีจากการออกกำลัง',
        'sport.placeholder': 'แคลอรีที่เผาผลาญ (เช่น 300)',
        'sport.add': 'เพิ่มในขีดจำกัดของวันนี้',
        'sport.msg': 'ใส่จำนวนแคลอรีที่เผาผลาญระหว่างการออกกำลังกาย จะถูกเพิ่มในขีดจำกัดรายวันสำหรับวันนี้เท่านั้น.'
    },
    'vi': {
        'sport.title': 'Thưởng calo tập luyện',
        'sport.placeholder': 'Calo đốt (vd: 300)',
        'sport.add': 'Thêm vào hạn mức hôm nay',
        'sport.msg': 'Nhập số calo đã đốt trong buổi tập. Sẽ được cộng vào hạn mức calo hằng ngày chỉ cho hôm nay.'
    },
    'ja': {
        'sport.title': '運動カロリーボーナス',
        'sport.placeholder': '消費カロリー（例：300）',
        'sport.add': '本日の上限に追加',
        'sport.msg': 'トレーニングで消費したカロリーを入力してください。本日のみ、1日の上限に加算されます。'
    },
    'ko': {
        'sport.title': '운동 칼로리 보너스',
        'sport.placeholder': '소모 칼로리(예: 300)',
        'sport.add': '오늘 한도에 추가',
        'sport.msg': '운동 중 소모한 칼로리를 입력하세요. 오늘에 한해 일일 한도에 추가됩니다.'
    },
    'zh': {
        'sport.title': '运动卡路里加成',
        'sport.placeholder': '消耗的卡路里（如 300）',
        'sport.add': '加入今天的上限',
        'sport.msg': '请输入您在锻炼中消耗的卡路里。该数值仅在今天添加到您的每日上限。'
    },
    'et': {
        'sport.title': 'Treeningkalorite boonus',
        'sport.placeholder': 'Põletatud kalorid (nt 300)',
        'sport.add': 'Lisa tänasele piirile',
        'sport.msg': 'Sisesta treeningu ajal põletatud kalorite arv. See liidetakse sinu päevapiirile ainult täna.'
    },
    'lv': {
        'sport.title': 'Treniņa kaloriju bonuss',
        'sport.placeholder': 'Sadedzinātās kalorijas (piem., 300)',
        'sport.add': 'Pievienot šodienas limitam',
        'sport.msg': 'Ievadiet treniņā sadedzināto kaloriju skaitu. Tās tiks pieskaitītas dienas limitam tikai šodien.'
    },
    'lt': {
        'sport.title': 'Treniruotės kalorijų bonusas',
        'sport.placeholder': 'Sunaudotos kalorijos (pvz., 300)',
        'sport.add': 'Pridėti prie šiandienos limito',
        'sport.msg': 'Įveskite treniruotėje sudegintas kalorijas. Jos bus pridėtos prie dienos limito tik šiandien.'
    },
    'mt': {
        'sport.title': 'Bonus tal-kaloriji tal-eżerċizzju',
        'sport.placeholder': 'Kaloriji maħruqa (eż. 300)',
        'sport.add': 'Żid mal-limitu ta’ llum',
        'sport.msg': 'Daħħal in-numru ta’ kaloriji maħruqa waqt l-eżerċizzju. Dan jiżdied mal-limitu ta’ kuljum għall-lum biss.'
    },
    'ga': {
        'sport.title': 'Bónas calraí aclaíochta',
        'sport.placeholder': 'Calraí dóite (m.sh., 300)',
        'sport.add': 'Cuir le teorainn an lae inniu',
        'sport.msg': 'Iontráil líon na gcalraí a dhóigh tú le linn an chleachtaidh. Cuirfear le do theorainn laethúil é don lá inniu amháin.'
    },
    'hr': {
        'sport.title': 'Bonus kalorija od vježbanja',
        'sport.placeholder': 'Potrošene kalorije (npr. 300)',
        'sport.add': 'Dodaj današnjem limitu',
        'sport.msg': 'Unesite broj kalorija potrošenih tijekom treninga. Zbrojit će se vašem dnevnom limitu samo danas.'
    },
    'hu': {
        'sport.title': 'Edzéskalória-bónusz',
        'sport.placeholder': 'Elégetett kalóriák (pl. 300)',
        'sport.add': 'Hozzáadás a mai kerethez',
        'sport.msg': 'Adja meg az edzés során elégetett kalóriákat. Csak mára kerül hozzáadásra a napi keretéhez.'
    },
}


def update_file(path: str, code: str) -> bool:
    try:
        with open(path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception as e:
        print(f"Skip {path}: {e}")
        return False
    trans = SPORT.get(code, SPORT['en'])
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
