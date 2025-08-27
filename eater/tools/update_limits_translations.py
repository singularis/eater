import json
import os
from glob import glob

ROOT = os.path.dirname(os.path.dirname(__file__))
LOCALE_DIR = os.path.join(ROOT, 'Localization')

LIMITS = {
    'en': {
        'limits.title': 'Set Calorie Limits',
        'limits.soft': 'Soft Limit',
        'limits.hard': 'Hard Limit',
        'limits.save_manual': 'Save Manual Limits',
        'limits.use_health': 'Use Health-Based Calculation',
        'limits.msg': 'Set your daily calorie limits manually, or use health-based calculation if you have health data.\n\n⚠️ These are general guidelines. Consult a healthcare provider for personalized dietary advice.',
        'limits.invalid_input_title': 'Invalid Input',
        'limits.invalid_input_msg': 'Please enter valid positive numbers. Soft limit must be less than or equal to hard limit.'
    },
    'es': {
        'limits.title': 'Establecer límites de calorías',
        'limits.soft': 'Límite suave',
        'limits.hard': 'Límite duro',
        'limits.save_manual': 'Guardar límites manuales',
        'limits.use_health': 'Usar cálculo basado en salud',
        'limits.msg': 'Establece tus límites diarios de calorías manualmente, o usa el cálculo basado en datos de salud si los tienes.\n\n⚠️ Estas son pautas generales. Consulta a un profesional para asesoramiento dietético personalizado.',
        'limits.invalid_input_title': 'Entrada no válida',
        'limits.invalid_input_msg': 'Introduce números positivos válidos. El límite suave debe ser menor o igual que el límite duro.'
    },
    'fr': {
        'limits.title': 'Définir les limites caloriques',
        'limits.soft': 'Limite souple',
        'limits.hard': 'Limite dure',
        'limits.save_manual': 'Enregistrer les limites manuelles',
        'limits.use_health': 'Utiliser le calcul basé sur la santé',
        'limits.msg': 'Définissez vos limites caloriques quotidiennes manuellement, ou utilisez le calcul basé sur vos données de santé si disponibles.\n\n⚠️ Il s’agit de lignes directrices générales. Consultez un professionnel de santé pour un conseil personnalisé.',
        'limits.invalid_input_title': 'Entrée invalide',
        'limits.invalid_input_msg': 'Veuillez saisir des nombres positifs valides. La limite souple doit être inférieure ou égale à la limite dure.'
    },
    'de': {
        'limits.title': 'Kaloriengrenzen festlegen',
        'limits.soft': 'Weiche Grenze',
        'limits.hard': 'Harte Grenze',
        'limits.save_manual': 'Manuelle Grenzen speichern',
        'limits.use_health': 'Gesundheitsbasierten Rechner verwenden',
        'limits.msg': 'Lege deine täglichen Kaloriengrenzen manuell fest oder nutze die gesundheitsbasierte Berechnung, falls Daten vorhanden sind.\n\n⚠️ Dies sind allgemeine Richtlinien. Bitte konsultiere für persönliche Beratung Fachpersonal.',
        'limits.invalid_input_title': 'Ungültige Eingabe',
        'limits.invalid_input_msg': 'Bitte gültige positive Zahlen eingeben. Die weiche Grenze muss kleiner oder gleich der harten Grenze sein.'
    },
    'it': {
        'limits.title': 'Imposta limiti calorici',
        'limits.soft': 'Limite soft',
        'limits.hard': 'Limite hard',
        'limits.save_manual': 'Salva limiti manuali',
        'limits.use_health': 'Usa calcolo basato sulla salute',
        'limits.msg': 'Imposta manualmente i limiti calorici giornalieri oppure usa il calcolo basato sui dati di salute se disponibili.\n\n⚠️ Linee guida generali: consulta un professionista per consigli personalizzati.',
        'limits.invalid_input_title': 'Dati non validi',
        'limits.invalid_input_msg': 'Inserisci numeri positivi validi. Il limite soft deve essere ≤ del limite hard.'
    },
    'pt': {
        'limits.title': 'Definir limites de calorias',
        'limits.soft': 'Limite suave',
        'limits.hard': 'Limite rígido',
        'limits.save_manual': 'Salvar limites manuais',
        'limits.use_health': 'Usar cálculo baseado na saúde',
        'limits.msg': 'Defina seus limites diários de calorias manualmente, ou use o cálculo baseado em dados de saúde se disponíveis.\n\n⚠️ São diretrizes gerais. Consulte um profissional para orientação personalizada.',
        'limits.invalid_input_title': 'Entrada inválida',
        'limits.invalid_input_msg': 'Insira números positivos válidos. O limite suave deve ser menor ou igual ao limite rígido.'
    },
    'pl': {
        'limits.title': 'Ustaw limity kalorii',
        'limits.soft': 'Limit miękki',
        'limits.hard': 'Limit twardy',
        'limits.save_manual': 'Zapisz limity ręczne',
        'limits.use_health': 'Użyj obliczeń na podstawie zdrowia',
        'limits.msg': 'Ustaw dzienne limity kalorii ręcznie lub skorzystaj z obliczeń na podstawie danych zdrowotnych, jeśli je posiadasz.\n\n⚠️ To ogólne wytyczne. Skonsultuj się ze specjalistą po spersonalizowane porady.',
        'limits.invalid_input_title': 'Nieprawidłowe dane',
        'limits.invalid_input_msg': 'Wpisz poprawne dodatnie liczby. Limit miękki musi być mniejszy lub równy limitowi twardemu.'
    },
    'nl': {
        'limits.title': 'Calorielimieten instellen',
        'limits.soft': 'Zachte limiet',
        'limits.hard': 'Harde limiet',
        'limits.save_manual': 'Handmatige limieten opslaan',
        'limits.use_health': 'Gezondheidsgebaseerde berekening gebruiken',
        'limits.msg': 'Stel je dagelijkse calorielimieten handmatig in, of gebruik de berekening op basis van gezondheidsgegevens.\n\n⚠️ Dit zijn algemene richtlijnen. Raadpleeg een professional voor persoonlijk advies.',
        'limits.invalid_input_title': 'Ongeldige invoer',
        'limits.invalid_input_msg': 'Voer geldige positieve getallen in. De zachte limiet moet ≤ de harde limiet zijn.'
    },
    'sv': {
        'limits.title': 'Ange kalorigränser',
        'limits.soft': 'Mjuk gräns',
        'limits.hard': 'Hård gräns',
        'limits.save_manual': 'Spara manuella gränser',
        'limits.use_health': 'Använd hälso-baserad beräkning',
        'limits.msg': 'Ange dina dagliga kalorigränser manuellt, eller använd beräkning baserad på hälsodata om tillgängligt.\n\n⚠️ Allmänna riktlinjer. Rådfråga vårdpersonal för personliga råd.',
        'limits.invalid_input_title': 'Ogiltig inmatning',
        'limits.invalid_input_msg': 'Ange giltiga positiva tal. Mjuk gräns måste vara ≤ hård gräns.'
    },
    'da': {
        'limits.title': 'Angiv kaloriegrænser',
        'limits.soft': 'Blød grænse',
        'limits.hard': 'Hård grænse',
        'limits.save_manual': 'Gem manuelle grænser',
        'limits.use_health': 'Brug sundhedsbaseret beregning',
        'limits.msg': 'Angiv dine daglige kaloriegrænser manuelt, eller brug sundhedsdata hvis tilgængeligt.\n\n⚠️ Generelle retningslinjer. Kontakt sundhedspersonale for personlig rådgivning.',
        'limits.invalid_input_title': 'Ugyldig indtastning',
        'limits.invalid_input_msg': 'Indtast gyldige positive tal. Den bløde grænse skal være ≤ den hårde grænse.'
    },
    'fi': {
        'limits.title': 'Aseta kalorirajat',
        'limits.soft': 'Pehmeä raja',
        'limits.hard': 'Kova raja',
        'limits.save_manual': 'Tallenna manuaaliset rajat',
        'limits.use_health': 'Käytä terveyspohjaista laskentaa',
        'limits.msg': 'Aseta päivittäiset kalorirajat manuaalisesti tai käytä terveysdatoihin perustuvaa laskentaa.\n\n⚠️ Yleisiä ohjeita. Kysy terveydenhuollon ammattilaiselta henkilökohtaista neuvontaa.',
        'limits.invalid_input_title': 'Virheellinen syöte',
        'limits.invalid_input_msg': 'Syötä kelvollisia positiivisia lukuja. Pehmeän rajan tulee olla ≤ kovan rajan.'
    },
    'cs': {
        'limits.title': 'Nastavit kalorické limity',
        'limits.soft': 'Měkký limit',
        'limits.hard': 'Tvrdý limit',
        'limits.save_manual': 'Uložit ruční limity',
        'limits.use_health': 'Použít výpočet dle zdraví',
        'limits.msg': 'Nastavte denní kalorické limity ručně, nebo použijte výpočet dle zdravotních údajů, pokud je máte.\n\n⚠️ Obecné pokyny. Pro osobní rady kontaktujte odborníka.',
        'limits.invalid_input_title': 'Neplatný vstup',
        'limits.invalid_input_msg': 'Zadejte platná kladná čísla. Měkký limit musí být ≤ tvrdému limitu.'
    },
    'sk': {
        'limits.title': 'Nastaviť kalorické limity',
        'limits.soft': 'Mäkký limit',
        'limits.hard': 'Tvrdý limit',
        'limits.save_manual': 'Uložiť manuálne limity',
        'limits.use_health': 'Použiť výpočet podľa zdravia',
        'limits.msg': 'Nastavte si denné kalorické limity manuálne alebo použite výpočet na základe zdravotných údajov, ak ich máte.\n\n⚠️ Ide o všeobecné usmernenia. Pre individuálne rady sa poraďte s odborníkom.',
        'limits.invalid_input_title': 'Neplatný vstup',
        'limits.invalid_input_msg': 'Zadajte platné kladné čísla. Mäkký limit musí byť ≤ tvrdému limitu.'
    },
    'sl': {
        'limits.title': 'Nastavi kalorijske meje',
        'limits.soft': 'Mehka meja',
        'limits.hard': 'Trda meja',
        'limits.save_manual': 'Shrani ročne meje',
        'limits.use_health': 'Uporabi izračun na podlagi zdravja',
        'limits.msg': 'Dnevne kalorijske meje nastavite ročno ali uporabite izračun na podlagi zdravstvenih podatkov.\n\n⚠️ Splošne smernice. Za osebni nasvet se posvetujte s strokovnjakom.',
        'limits.invalid_input_title': 'Neveljaven vnos',
        'limits.invalid_input_msg': 'Vnesite veljavna pozitivna števila. Mehka meja mora biti ≤ trdi meji.'
    },
    'ro': {
        'limits.title': 'Setează limitele de calorii',
        'limits.soft': 'Limită moale',
        'limits.hard': 'Limită dură',
        'limits.save_manual': 'Salvează limitele manuale',
        'limits.use_health': 'Folosește calcul bazat pe sănătate',
        'limits.msg': 'Stabilește limitele zilnice de calorii manual sau folosește calculul bazat pe date de sănătate dacă le ai.\n\n⚠️ Recomandări generale. Consultă un specialist pentru sfaturi personalizate.',
        'limits.invalid_input_title': 'Date invalide',
        'limits.invalid_input_msg': 'Introduceți numere pozitive valide. Limita moale trebuie să fie ≤ limitei dure.'
    },
    'bg': {
        'limits.title': 'Задаване на калорийни граници',
        'limits.soft': 'Мека граница',
        'limits.hard': 'Твърда граница',
        'limits.save_manual': 'Запази ръчни граници',
        'limits.use_health': 'Използвай изчисление по здравни данни',
        'limits.msg': 'Задайте дневните калорийни граници ръчно или използвайте изчисление въз основа на здравни данни.\n\n⚠️ Общи насоки. За персонализиран съвет се консултирайте със специалист.',
        'limits.invalid_input_title': 'Невалидни данни',
        'limits.invalid_input_msg': 'Въведете валидни положителни числа. Меката граница трябва да е ≤ твърдата.'
    },
    'be': {
        'limits.title': 'Усталяваць ліміты калорый',
        'limits.soft': 'Мяккі ліміт',
        'limits.hard': 'Цвёрды ліміт',
        'limits.save_manual': 'Захаваць ручныя ліміты',
        'limits.use_health': 'Выкарыстоўваць разлік паводле здароўя',
        'limits.msg': 'Усталюйце дзённыя ліміты калорый уручную або скарыстайцеся разлікам на падставе дадзеных пра здароўе.\n\n⚠️ Гэта агульныя рэкамендацыі. Звярніцеся да спецыяліста для персанальных парад.',
        'limits.invalid_input_title': 'Няправільны ўвод',
        'limits.invalid_input_msg': 'Увядзіце карэктныя станоўчыя лікі. Мяккі ліміт павінен быць ≤ цвёрдага.'
    },
    'uk': {
        'limits.title': 'Встановити калорійні ліміти',
        'limits.soft': 'Мʼякий ліміт',
        'limits.hard': 'Жорсткий ліміт',
        'limits.save_manual': 'Зберегти ручні ліміти',
        'limits.use_health': 'Використати розрахунок на основі здоровʼя',
        'limits.msg': 'Встановіть денні ліміти калорій вручну або скористайтеся розрахунком на основі даних про здоровʼя.\n\n⚠️ Це загальні рекомендації. Для персональних порад зверніться до фахівця.',
        'limits.invalid_input_title': 'Неправильні дані',
        'limits.invalid_input_msg': 'Введіть дійсні додатні числа. Мʼякий ліміт має бути ≤ жорсткого.'
    },
    'el': {
        'limits.title': 'Ορισμός ορίων θερμίδων',
        'limits.soft': 'Ήπιο όριο',
        'limits.hard': 'Αυστηρό όριο',
        'limits.save_manual': 'Αποθήκευση χειροκίνητων ορίων',
        'limits.use_health': 'Χρήση υπολογισμού βάσει υγείας',
        'limits.msg': 'Ορίστε τα ημερήσια όρια θερμίδων χειροκίνητα ή χρησιμοποιήστε υπολογισμό βάσει δεδομένων υγείας.\n\n⚠️ Γενικές οδηγίες. Συμβουλευτείτε ειδικό για εξατομικευμένη καθοδήγηση.',
        'limits.invalid_input_title': 'Μη έγκυρη εισαγωγή',
        'limits.invalid_input_msg': 'Εισαγάγετε έγκυρους θετικούς αριθμούς. Το ήπιο όριο πρέπει να είναι ≤ του αυστηρού ορίου.'
    },
    'tr': {
        'limits.title': 'Kalori sınırlarını ayarla',
        'limits.soft': 'Yumuşak sınır',
        'limits.hard': 'Sert sınır',
        'limits.save_manual': 'Manuel sınırları kaydet',
        'limits.use_health': 'Sağlık bazlı hesaplama kullan',
        'limits.msg': 'Günlük kalori sınırlarını manuel ayarlayın veya sağlık verilerine dayalı hesaplamayı kullanın.\n\n⚠️ Bunlar genel yönergelerdir. Kişisel tavsiye için uzmanla görüşün.',
        'limits.invalid_input_title': 'Geçersiz giriş',
        'limits.invalid_input_msg': 'Geçerli pozitif sayılar girin. Yumuşak sınır sert sınırdan büyük olmamalı.'
    },
    'ar': {
        'limits.title': 'تعيين حدود السعرات الحرارية',
        'limits.soft': 'حد مرن',
        'limits.hard': 'حد صارم',
        'limits.save_manual': 'حفظ الحدود اليدوية',
        'limits.use_health': 'استخدام حساب قائم على الصحة',
        'limits.msg': 'قم بتعيين حدود السعرات اليومية يدويًا، أو استخدم الحساب بناءً على بيانات الصحة إن وُجدت.\n\n⚠️ هذه إرشادات عامة. استشر مختصًا للحصول على نصيحة غذائية مخصصة.',
        'limits.invalid_input_title': 'إدخال غير صالح',
        'limits.invalid_input_msg': 'يرجى إدخال أرقام موجبة صالحة. يجب أن يكون الحد المرن ≤ الحد الصارم.'
    },
    'ur': {
        'limits.title': 'کیلوری حدود مقرر کریں',
        'limits.soft': 'نرم حد',
        'limits.hard': 'سخت حد',
        'limits.save_manual': 'دستی حدود محفوظ کریں',
        'limits.use_health': 'صحت پر مبنی حساب استعمال کریں',
        'limits.msg': 'اپنی روزانہ کیلوری کی حدیں دستی طور پر مقرر کریں، یا صحت کے ڈیٹا پر مبنی حساب استعمال کریں۔\n\n⚠️ یہ عمومی رہنما اصول ہیں۔ ذاتی مشورے کے لیے ماہر سے رجوع کریں۔',
        'limits.invalid_input_title': 'غلط اندراج',
        'limits.invalid_input_msg': 'براہ کرم درست مثبت نمبرز درج کریں۔ نرم حد سخت حد کے برابر یا اس سے کم ہونی چاہیے۔'
    },
    'hi': {
        'limits.title': 'कैलोरी सीमाएँ सेट करें',
        'limits.soft': 'सॉफ्ट सीमा',
        'limits.hard': 'हार्ड सीमा',
        'limits.save_manual': 'मैन्युअल सीमाएँ सहेजें',
        'limits.use_health': 'स्वास्थ्य-आधारित गणना का उपयोग करें',
        'limits.msg': 'अपनी दैनिक कैलोरी सीमाएँ मैन्युअल रूप से सेट करें, या स्वास्थ्य डेटा पर आधारित गणना का उपयोग करें।\n\n⚠️ ये सामान्य दिशानिर्देश हैं। व्यक्तिगत सलाह के लिए विशेषज्ञ से परामर्श करें।',
        'limits.invalid_input_title': 'अमान्य इनपुट',
        'limits.invalid_input_msg': 'कृपया वैध धनात्मक संख्याएँ दर्ज करें। सॉफ्ट सीमा हार्ड सीमा से कम या बराबर होनी चाहिए।'
    },
    'bn': {
        'limits.title': 'ক্যালোরি সীমা নির্ধারণ করুন',
        'limits.soft': 'সফট লিমিট',
        'limits.hard': 'হার্ড লিমিট',
        'limits.save_manual': 'ম্যানুয়াল সীমা সংরক্ষণ করুন',
        'limits.use_health': 'স্বাস্থ্য-ভিত্তিক হিসাব ব্যবহার করুন',
        'limits.msg': 'আপনার দৈনিক ক্যালোরি সীমা ম্যানুয়ালি সেট করুন, অথবা স্বাস্থ্য ডেটার উপর ভিত্তি করে হিসাব ব্যবহার করুন।\n\n⚠️ এগুলি সাধারণ নির্দেশিকা। ব্যক্তিগত পরামর্শের জন্য বিশেষজ্ঞের সাথে পরামর্শ করুন।',
        'limits.invalid_input_title': 'অবৈধ ইনপুট',
        'limits.invalid_input_msg': 'দয়া করে বৈধ ধনাত্মক সংখ্যা লিখুন। সফট লিমিট হার্ড লিমিটের সমান বা কম হতে হবে।'
    },
    'th': {
        'limits.title': 'ตั้งค่าขีดจำกัดแคลอรี',
        'limits.soft': 'ขีดจำกัดแบบนุ่ม',
        'limits.hard': 'ขีดจำกัดแบบเข้มงวด',
        'limits.save_manual': 'บันทึกขีดจำกัดแบบกำหนดเอง',
        'limits.use_health': 'ใช้การคำนวณตามสุขภาพ',
        'limits.msg': 'ตั้งค่าขีดจำกัดแคลอรีรายวันด้วยตนเอง หรือใช้การคำนวณตามข้อมูลสุขภาพถ้ามี\n\n⚠️ เป็นแนวทางทั่วไป ควรปรึกษาผู้เชี่ยวชาญเพื่อคำแนะนำเฉพาะบุคคล',
        'limits.invalid_input_title': 'ข้อมูลไม่ถูกต้อง',
        'limits.invalid_input_msg': 'กรุณากรอกตัวเลขบวกที่ถูกต้อง ขีดจำกัดแบบนุ่มต้อง ≤ ขีดจำกัดแบบเข้มงวด'
    },
    'vi': {
        'limits.title': 'Đặt giới hạn calo',
        'limits.soft': 'Giới hạn mềm',
        'limits.hard': 'Giới hạn cứng',
        'limits.save_manual': 'Lưu giới hạn thủ công',
        'limits.use_health': 'Dùng tính toán dựa trên sức khỏe',
        'limits.msg': 'Đặt giới hạn calo hằng ngày thủ công, hoặc dùng tính toán dựa trên dữ liệu sức khỏe nếu có.\n\n⚠️ Đây là hướng dẫn chung. Hãy tham khảo chuyên gia để được tư vấn cá nhân hóa.',
        'limits.invalid_input_title': 'Dữ liệu không hợp lệ',
        'limits.invalid_input_msg': 'Vui lòng nhập số dương hợp lệ. Giới hạn mềm phải ≤ giới hạn cứng.'
    },
    'ja': {
        'limits.title': 'カロリー上限を設定',
        'limits.soft': 'ソフト上限',
        'limits.hard': 'ハード上限',
        'limits.save_manual': '手動上限を保存',
        'limits.use_health': '健康データに基づく計算を使用',
        'limits.msg': '日々のカロリー上限を手動で設定するか、健康データに基づく計算を使用してください。\n\n⚠️ これは一般的なガイドラインです。個別の助言は専門家にご相談ください。',
        'limits.invalid_input_title': '無効な入力',
        'limits.invalid_input_msg': '有効な正の数を入力してください。ソフト上限はハード上限以下でなければなりません。'
    },
    'ko': {
        'limits.title': '칼로리 한도 설정',
        'limits.soft': '소프트 한도',
        'limits.hard': '하드 한도',
        'limits.save_manual': '수동 한도 저장',
        'limits.use_health': '건강 기반 계산 사용',
        'limits.msg': '일일 칼로리 한도를 수동으로 설정하거나, 건강 데이터 기반 계산을 사용하세요.\n\n⚠️ 일반 지침입니다. 개인 맞춤 조언은 전문가와 상담하세요.',
        'limits.invalid_input_title': '잘못된 입력',
        'limits.invalid_input_msg': '유효한 양수를 입력하세요. 소프트 한도는 하드 한도 이하이어야 합니다.'
    },
    'zh': {
        'limits.title': '设置卡路里上限',
        'limits.soft': '宽松上限',
        'limits.hard': '严格上限',
        'limits.save_manual': '保存手动上限',
        'limits.use_health': '使用基于健康的计算',
        'limits.msg': '手动设置每日卡路里上限，或在有健康数据时使用健康计算。\n\n⚠️ 以上为一般性建议。个性化饮食建议请咨询专业人士。',
        'limits.invalid_input_title': '无效输入',
        'limits.invalid_input_msg': '请输入有效的正数。宽松上限必须小于或等于严格上限。'
    },
    'et': {
        'limits.title': 'Määra kaloripiirid',
        'limits.soft': 'Pehme piir',
        'limits.hard': 'Range piir',
        'limits.save_manual': 'Salvesta käsitsi piirid',
        'limits.use_health': 'Kasuta tervisepõhist arvutust',
        'limits.msg': 'Sea igapäevased kaloripiirid käsitsi või kasuta terviseandmetel põhinevat arvutust.\n\n⚠️ Üldised juhised. Isikupärastatud nõu saamiseks konsulteeri spetsialistiga.',
        'limits.invalid_input_title': 'Vigane sisend',
        'limits.invalid_input_msg': 'Sisesta kehtivad positiivsed arvud. Pehme piir peab olema ≤ rangele piirile.'
    },
    'lv': {
        'limits.title': 'Iestatīt kaloriju ierobežojumus',
        'limits.soft': 'Mīkstais ierobežojums',
        'limits.hard': 'Stingrais ierobežojums',
        'limits.save_manual': 'Saglabāt manuālos ierobežojumus',
        'limits.use_health': 'Lietot uz veselību balstītu aprēķinu',
        'limits.msg': 'Iestatiet ikdienas kaloriju ierobežojumus manuāli vai izmantojiet aprēķinu, kas balstīts uz veselības datiem.\n\n⚠️ Vispārīgi ieteikumi. Personīgai konsultācijai sazinieties ar speciālistu.',
        'limits.invalid_input_title': 'Nederīga ievade',
        'limits.invalid_input_msg': 'Lūdzu, ievadiet derīgus pozitīvus skaitļus. Mīkstais ierobežojums nedrīkst pārsniegt stingro.'
    },
    'lt': {
        'limits.title': 'Nustatyti kalorijų ribas',
        'limits.soft': 'Lanksti riba',
        'limits.hard': 'Griežta riba',
        'limits.save_manual': 'Išsaugoti rankiniu būdu',
        'limits.use_health': 'Naudoti sveikatos pagrįstą skaičiavimą',
        'limits.msg': 'Nustatykite dienos kalorijų ribas rankiniu būdu arba naudokite skaičiavimą pagal sveikatos duomenis.\n\n⚠️ Tai bendros gairės. Dėl asmeninių patarimų kreipkitės į specialistą.',
        'limits.invalid_input_title': 'Neteisingi duomenys',
        'limits.invalid_input_msg': 'Įveskite teisingus teigiamus skaičius. Lanksti riba turi būti ≤ griežtos ribos.'
    },
    'mt': {
        'limits.title': 'Stabbilix limiti tal-kaloriji',
        'limits.soft': 'Limitu artab',
        'limits.hard': 'Limitu iebes',
        'limits.save_manual': 'Issejvja limiti manwali',
        'limits.use_health': 'Uża kalkolu bbażat fuq is-saħħa',
        'limits.msg': 'Stabbilix il-limiti ta’ kuljum manwalment jew uża kalkolu bbażat fuq data tas-saħħa.\n\n⚠️ Gwida ġenerali. Għal parir personalizzat ikkonsulta professjonist.',
        'limits.invalid_input_title': 'Input invalidu',
        'limits.invalid_input_msg': 'Daħħal numri pożittivi validi. Il-limitu artab għandu jkun ≤ tal-limitu iebes.'
    },
    'ga': {
        'limits.title': 'Socraigh teorainneacha calraí',
        'limits.soft': 'Teorainn bhog',
        'limits.hard': 'Teorainn chrua',
        'limits.save_manual': 'Sábháil teorainneacha láimhe',
        'limits.use_health': 'Úsáid ríomh bunaithe ar shláinte',
        'limits.msg': 'Socraigh do theorainneacha calraí laethúla de láimh, nó bain úsáid as ríomh bunaithe ar shonraí sláinte.\n\n⚠️ Treoirlínte ginearálta. Le comhairle phearsantaithe, téigh i gcomhairle le speisialtóir.',
        'limits.invalid_input_title': 'Ionchur neamhbhailí',
        'limits.invalid_input_msg': 'Iontráil uimhreacha dearfacha bailí. Ní mór don teorainn bhog a bheith ≤ na teora crua.'
    },
    'hr': {
        'limits.title': 'Postavi granice kalorija',
        'limits.soft': 'Meka granica',
        'limits.hard': 'Tvrda granica',
        'limits.save_manual': 'Spremi ručne granice',
        'limits.use_health': 'Koristi izračun temeljen na zdravlju',
        'limits.msg': 'Postavite dnevne granice kalorija ručno ili koristite izračun temeljen na zdravstvenim podacima.\n\n⚠️ Opće smjernice. Za osobni savjet obratite se stručnjaku.',
        'limits.invalid_input_title': 'Nevažeći unos',
        'limits.invalid_input_msg': 'Unesite valjane pozitivne brojeve. Meka granica mora biti ≤ tvrde granice.'
    },
    'hu': {
        'limits.title': 'Kalóriahatárok beállítása',
        'limits.soft': 'Puha határ',
        'limits.hard': 'Szigorú határ',
        'limits.save_manual': 'Kézi határok mentése',
        'limits.use_health': 'Egészség-alapú számítás használata',
        'limits.msg': 'Állítsa be a napi kalóriahatárokat kézzel, vagy használja az egészségügyi adatokon alapuló számítást.\n\n⚠️ Általános iránymutatások. Személyre szabott tanácsért forduljon szakemberhez.',
        'limits.invalid_input_title': 'Érvénytelen bevitel',
        'limits.invalid_input_msg': 'Érvényes pozitív számokat adjon meg. A puha határnak ≤ a szigorú határnak kell lennie.'
    },
}


def update_file(path: str, code: str) -> bool:
    try:
        with open(path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception as e:
        print(f"Skip {path}: {e}")
        return False
    trans = LIMITS.get(code, LIMITS['en'])
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
