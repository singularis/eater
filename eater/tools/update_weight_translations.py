import json
import os
from glob import glob

ROOT = os.path.dirname(os.path.dirname(__file__))
LOCALE_DIR = os.path.join(ROOT, 'Localization')

# Keys we will populate
WEIGHT_KEYS = [
    'weight.record.title',
    'weight.take_photo',
    'weight.manual_entry',
    'weight.record.msg',
    'weight.enter.title',
    'weight.enter.placeholder',
    'weight.enter.msg',
    'weight.invalid.title',
    'weight.invalid.msg',
    'weight.need_login',
    'weight.recorded.title',
    'weight.recorded.msg',
    'weight.record_failed.msg',
]

WEIGHT = {
    'en': {
        'weight.record.title': 'Record Weight',
        'weight.take_photo': 'Take Photo',
        'weight.manual_entry': 'Manual Entry',
        'weight.record.msg': "Choose how you'd like to record your weight",
        'weight.enter.title': 'Enter Weight',
        'weight.enter.placeholder': 'Weight (kg)',
        'weight.enter.msg': 'Enter your weight in kilograms',
        'weight.invalid.title': 'Invalid Weight',
        'weight.invalid.msg': 'Please enter a valid weight in kilograms.',
        'weight.need_login': 'Unable to submit weight. Please sign in again.',
        'weight.recorded.title': 'Weight Recorded',
        'weight.recorded.msg': 'Your weight has been successfully recorded.',
        'weight.record_failed.msg': 'Failed to record your weight. Please try again.'
    },
    'es': {
        'weight.record.title': 'Registrar peso',
        'weight.take_photo': 'Tomar foto',
        'weight.manual_entry': 'Entrada manual',
        'weight.record.msg': 'Elige cómo deseas registrar tu peso',
        'weight.enter.title': 'Ingresar peso',
        'weight.enter.placeholder': 'Peso (kg)',
        'weight.enter.msg': 'Ingresa tu peso en kilogramos',
        'weight.invalid.title': 'Peso no válido',
        'weight.invalid.msg': 'Ingresa un peso válido en kilogramos.',
        'weight.need_login': 'No se puede enviar el peso. Vuelve a iniciar sesión.',
        'weight.recorded.title': 'Peso registrado',
        'weight.recorded.msg': 'Tu peso se ha registrado correctamente.',
        'weight.record_failed.msg': 'No se pudo registrar tu peso. Inténtalo de nuevo.'
    },
    'fr': {
        'weight.record.title': 'Enregistrer le poids',
        'weight.take_photo': 'Prendre une photo',
        'weight.manual_entry': 'Saisie manuelle',
        'weight.record.msg': 'Choisissez comment enregistrer votre poids',
        'weight.enter.title': 'Saisir le poids',
        'weight.enter.placeholder': 'Poids (kg)',
        'weight.enter.msg': 'Entrez votre poids en kilogrammes',
        'weight.invalid.title': 'Poids invalide',
        'weight.invalid.msg': 'Veuillez entrer un poids valide en kilogrammes.',
        'weight.need_login': 'Impossible d’envoyer le poids. Veuillez vous reconnecter.',
        'weight.recorded.title': 'Poids enregistré',
        'weight.recorded.msg': 'Votre poids a été enregistré avec succès.',
        'weight.record_failed.msg': "Échec de l'enregistrement du poids. Veuillez réessayer."
    },
    'de': {
        'weight.record.title': 'Gewicht erfassen',
        'weight.take_photo': 'Foto aufnehmen',
        'weight.manual_entry': 'Manuelle Eingabe',
        'weight.record.msg': 'Wählen Sie aus, wie Sie Ihr Gewicht erfassen möchten',
        'weight.enter.title': 'Gewicht eingeben',
        'weight.enter.placeholder': 'Gewicht (kg)',
        'weight.enter.msg': 'Geben Sie Ihr Gewicht in Kilogramm ein',
        'weight.invalid.title': 'Ungültiges Gewicht',
        'weight.invalid.msg': 'Bitte geben Sie ein gültiges Gewicht in Kilogramm ein.',
        'weight.need_login': 'Gewicht kann nicht gesendet werden. Bitte melden Sie sich erneut an.',
        'weight.recorded.title': 'Gewicht erfasst',
        'weight.recorded.msg': 'Ihr Gewicht wurde erfolgreich erfasst.',
        'weight.record_failed.msg': 'Gewicht konnte nicht erfasst werden. Bitte erneut versuchen.'
    },
    'it': {
        'weight.record.title': 'Registrare il peso',
        'weight.take_photo': 'Scatta foto',
        'weight.manual_entry': 'Inserimento manuale',
        'weight.record.msg': 'Scegli come registrare il tuo peso',
        'weight.enter.title': 'Inserisci peso',
        'weight.enter.placeholder': 'Peso (kg)',
        'weight.enter.msg': 'Inserisci il tuo peso in chilogrammi',
        'weight.invalid.title': 'Peso non valido',
        'weight.invalid.msg': 'Inserisci un peso valido in chilogrammi.',
        'weight.need_login': 'Impossibile inviare il peso. Accedi di nuovo.',
        'weight.recorded.title': 'Peso registrato',
        'weight.recorded.msg': 'Il tuo peso è stato registrato con successo.',
        'weight.record_failed.msg': 'Registrazione del peso non riuscita. Riprova.'
    },
    'pt': {
        'weight.record.title': 'Registrar peso',
        'weight.take_photo': 'Tirar foto',
        'weight.manual_entry': 'Entrada manual',
        'weight.record.msg': 'Escolha como registrar seu peso',
        'weight.enter.title': 'Inserir peso',
        'weight.enter.placeholder': 'Peso (kg)',
        'weight.enter.msg': 'Insira seu peso em quilogramas',
        'weight.invalid.title': 'Peso inválido',
        'weight.invalid.msg': 'Insira um peso válido em quilogramas.',
        'weight.need_login': 'Não é possível enviar o peso. Faça login novamente.',
        'weight.recorded.title': 'Peso registrado',
        'weight.recorded.msg': 'Seu peso foi registrado com sucesso.',
        'weight.record_failed.msg': 'Falha ao registrar seu peso. Tente novamente.'
    },
    'pl': {
        'weight.record.title': 'Zapisz wagę',
        'weight.take_photo': 'Zrób zdjęcie',
        'weight.manual_entry': 'Wpis ręczny',
        'weight.record.msg': 'Wybierz, jak chcesz zapisać swoją wagę',
        'weight.enter.title': 'Wprowadź wagę',
        'weight.enter.placeholder': 'Waga (kg)',
        'weight.enter.msg': 'Wprowadź swoją wagę w kilogramach',
        'weight.invalid.title': 'Nieprawidłowa waga',
        'weight.invalid.msg': 'Wprowadź prawidłową wagę w kilogramach.',
        'weight.need_login': 'Nie można wysłać wagi. Zaloguj się ponownie.',
        'weight.recorded.title': 'Waga zapisana',
        'weight.recorded.msg': 'Twoja waga została pomyślnie zapisana.',
        'weight.record_failed.msg': 'Nie udało się zapisać wagi. Spróbuj ponownie.'
    },
    'nl': {
        'weight.record.title': 'Gewicht vastleggen',
        'weight.take_photo': 'Foto maken',
        'weight.manual_entry': 'Handmatige invoer',
        'weight.record.msg': 'Kies hoe je je gewicht wilt vastleggen',
        'weight.enter.title': 'Gewicht invoeren',
        'weight.enter.placeholder': 'Gewicht (kg)',
        'weight.enter.msg': 'Voer je gewicht in kilogram in',
        'weight.invalid.title': 'Ongeldig gewicht',
        'weight.invalid.msg': 'Voer een geldig gewicht in kilogram in.',
        'weight.need_login': 'Kan gewicht niet verzenden. Log opnieuw in.',
        'weight.recorded.title': 'Gewicht vastgelegd',
        'weight.recorded.msg': 'Je gewicht is succesvol vastgelegd.',
        'weight.record_failed.msg': 'Het vastleggen van je gewicht is mislukt. Probeer het opnieuw.'
    },
    'sv': {
        'weight.record.title': 'Registrera vikt',
        'weight.take_photo': 'Ta foto',
        'weight.manual_entry': 'Manuell inmatning',
        'weight.record.msg': 'Välj hur du vill registrera din vikt',
        'weight.enter.title': 'Ange vikt',
        'weight.enter.placeholder': 'Vikt (kg)',
        'weight.enter.msg': 'Ange din vikt i kilogram',
        'weight.invalid.title': 'Ogiltig vikt',
        'weight.invalid.msg': 'Ange en giltig vikt i kilogram.',
        'weight.need_login': 'Det går inte att skicka vikt. Logga in igen.',
        'weight.recorded.title': 'Vikt registrerad',
        'weight.recorded.msg': 'Din vikt har registrerats.',
        'weight.record_failed.msg': 'Det gick inte att registrera vikten. Försök igen.'
    },
    'da': {
        'weight.record.title': 'Registrer vægt',
        'weight.take_photo': 'Tag foto',
        'weight.manual_entry': 'Manuel indtastning',
        'weight.record.msg': 'Vælg, hvordan du vil registrere din vægt',
        'weight.enter.title': 'Indtast vægt',
        'weight.enter.placeholder': 'Vægt (kg)',
        'weight.enter.msg': 'Indtast din vægt i kilogram',
        'weight.invalid.title': 'Ugyldig vægt',
        'weight.invalid.msg': 'Indtast en gyldig vægt i kilogram.',
        'weight.need_login': 'Kan ikke indsende vægt. Log ind igen.',
        'weight.recorded.title': 'Vægt registreret',
        'weight.recorded.msg': 'Din vægt blev registreret.',
        'weight.record_failed.msg': 'Kunne ikke registrere vægt. Prøv igen.'
    },
    'fi': {
        'weight.record.title': 'Tallenna paino',
        'weight.take_photo': 'Ota kuva',
        'weight.manual_entry': 'Manuaalinen syöttö',
        'weight.record.msg': 'Valitse, miten haluat tallentaa painosi',
        'weight.enter.title': 'Syötä paino',
        'weight.enter.placeholder': 'Paino (kg)',
        'weight.enter.msg': 'Syötä painosi kilogrammoina',
        'weight.invalid.title': 'Virheellinen paino',
        'weight.invalid.msg': 'Syötä kelvollinen paino kilogrammoina.',
        'weight.need_login': 'Painoa ei voi lähettää. Kirjaudu sisään uudelleen.',
        'weight.recorded.title': 'Paino tallennettu',
        'weight.recorded.msg': 'Painosi on tallennettu onnistuneesti.',
        'weight.record_failed.msg': 'Painon tallennus epäonnistui. Yritä uudelleen.'
    },
    'cs': {
        'weight.record.title': 'Zaznamenat hmotnost',
        'weight.take_photo': 'Pořídit fotografii',
        'weight.manual_entry': 'Ruční zadání',
        'weight.record.msg': 'Zvolte, jak chcete zaznamenat svou hmotnost',
        'weight.enter.title': 'Zadat hmotnost',
        'weight.enter.placeholder': 'Hmotnost (kg)',
        'weight.enter.msg': 'Zadejte svou hmotnost v kilogramech',
        'weight.invalid.title': 'Neplatná hmotnost',
        'weight.invalid.msg': 'Zadejte platnou hmotnost v kilogramech.',
        'weight.need_login': 'Nelze odeslat hmotnost. Přihlaste se znovu.',
        'weight.recorded.title': 'Hmotnost zaznamenána',
        'weight.recorded.msg': 'Vaše hmotnost byla úspěšně zaznamenána.',
        'weight.record_failed.msg': 'Záznam hmotnosti selhal. Zkuste to znovu.'
    },
    'sk': {
        'weight.record.title': 'Zaznamenať hmotnosť',
        'weight.take_photo': 'Odfotiť',
        'weight.manual_entry': 'Manuálny záznam',
        'weight.record.msg': 'Vyberte, ako chcete zaznamenať vašu hmotnosť',
        'weight.enter.title': 'Zadať hmotnosť',
        'weight.enter.placeholder': 'Hmotnosť (kg)',
        'weight.enter.msg': 'Zadajte vašu hmotnosť v kilogramoch',
        'weight.invalid.title': 'Neplatná hmotnosť',
        'weight.invalid.msg': 'Zadajte platnú hmotnosť v kilogramoch.',
        'weight.need_login': 'Nie je možné odoslať hmotnosť. Prihláste sa znova.',
        'weight.recorded.title': 'Hmotnosť zaznamenaná',
        'weight.recorded.msg': 'Vaša hmotnosť bola úspešne zaznamenaná.',
        'weight.record_failed.msg': 'Záznam hmotnosti zlyhal. Skúste znova.'
    },
    'sl': {
        'weight.record.title': 'Zabeleži težo',
        'weight.take_photo': 'Posnemi fotografijo',
        'weight.manual_entry': 'Ročni vnos',
        'weight.record.msg': 'Izberite, kako želite zabeležiti svojo težo',
        'weight.enter.title': 'Vnesi težo',
        'weight.enter.placeholder': 'Teža (kg)',
        'weight.enter.msg': 'Vnesite težo v kilogramih',
        'weight.invalid.title': 'Neveljavna teža',
        'weight.invalid.msg': 'Vnesite veljavno težo v kilogramih.',
        'weight.need_login': 'Teže ni mogoče poslati. Prijavite se znova.',
        'weight.recorded.title': 'Teža zabeležena',
        'weight.recorded.msg': 'Vaša teža je bila uspešno zabeležena.',
        'weight.record_failed.msg': 'Zabeležitev teže ni uspela. Poskusite znova.'
    },
    'ro': {
        'weight.record.title': 'Înregistrează greutatea',
        'weight.take_photo': 'Fă o fotografie',
        'weight.manual_entry': 'Introducere manuală',
        'weight.record.msg': 'Alege cum vrei să îți înregistrezi greutatea',
        'weight.enter.title': 'Introdu greutatea',
        'weight.enter.placeholder': 'Greutate (kg)',
        'weight.enter.msg': 'Introdu greutatea în kilograme',
        'weight.invalid.title': 'Greutate invalidă',
        'weight.invalid.msg': 'Introdu o greutate validă în kilograme.',
        'weight.need_login': 'Nu se poate trimite greutatea. Autentifică-te din nou.',
        'weight.recorded.title': 'Greutate înregistrată',
        'weight.recorded.msg': 'Greutatea ta a fost înregistrată cu succes.',
        'weight.record_failed.msg': 'Nu s-a putut înregistra greutatea. Încearcă din nou.'
    },
    'bg': {
        'weight.record.title': 'Запис на тегло',
        'weight.take_photo': 'Снимай',
        'weight.manual_entry': 'Ръчно въвеждане',
        'weight.record.msg': 'Изберете как да запишете теглото си',
        'weight.enter.title': 'Въведете тегло',
        'weight.enter.placeholder': 'Тегло (kg)',
        'weight.enter.msg': 'Въведете теглото си в килограми',
        'weight.invalid.title': 'Невалидно тегло',
        'weight.invalid.msg': 'Въведете валидно тегло в килограми.',
        'weight.need_login': 'Не може да се изпрати теглото. Впишете се отново.',
        'weight.recorded.title': 'Теглото е записано',
        'weight.recorded.msg': 'Теглото ви е записано успешно.',
        'weight.record_failed.msg': 'Неуспешен запис на тегло. Опитайте отново.'
    },
    'be': {
        'weight.record.title': 'Запісаць вагу',
        'weight.take_photo': 'Зрабіць фота',
        'weight.manual_entry': 'Ручны ўвод',
        'weight.record.msg': 'Абярыце, як запісаць вашу вагу',
        'weight.enter.title': 'Увядзіце вагу',
        'weight.enter.placeholder': 'Вага (кг)',
        'weight.enter.msg': 'Увядзіце вашу вагу ў кілаграмах',
        'weight.invalid.title': 'Няправільная вага',
        'weight.invalid.msg': 'Увядзіце карэктную вагу ў кілаграмах.',
        'weight.need_login': 'Немагчыма адправіць вагу. Увайдзіце зноў.',
        'weight.recorded.title': 'Вага запісана',
        'weight.recorded.msg': 'Ваша вага паспяхова запісана.',
        'weight.record_failed.msg': 'Не ўдалося запісаць вагу. Паспрабуйце яшчэ.'
    },
    'uk': {
        'weight.record.title': 'Записати вагу',
        'weight.take_photo': 'Зробити фото',
        'weight.manual_entry': 'Ручне введення',
        'weight.record.msg': 'Виберіть, як ви хочете записати свою вагу',
        'weight.enter.title': 'Введіть вагу',
        'weight.enter.placeholder': 'Вага (кг)',
        'weight.enter.msg': 'Введіть вашу вагу в кілограмах',
        'weight.invalid.title': 'Неправильна вага',
        'weight.invalid.msg': 'Введіть дійсну вагу в кілограмах.',
        'weight.need_login': 'Не вдається надіслати вагу. Увійдіть знову.',
        'weight.recorded.title': 'Вагу записано',
        'weight.recorded.msg': 'Вашу вагу успішно записано.',
        'weight.record_failed.msg': 'Не вдалося записати вагу. Спробуйте ще раз.'
    },
    'el': {
        'weight.record.title': 'Καταγραφή βάρους',
        'weight.take_photo': 'Λήψη φωτογραφίας',
        'weight.manual_entry': 'Χειροκίνητη εισαγωγή',
        'weight.record.msg': 'Επιλέξτε πώς θέλετε να καταγράψετε το βάρος σας',
        'weight.enter.title': 'Εισαγωγή βάρους',
        'weight.enter.placeholder': 'Βάρος (kg)',
        'weight.enter.msg': 'Εισαγάγετε το βάρος σας σε κιλά',
        'weight.invalid.title': 'Μη έγκυρο βάρος',
        'weight.invalid.msg': 'Εισαγάγετε έγκυρο βάρος σε κιλά.',
        'weight.need_login': 'Δεν είναι δυνατή η υποβολή βάρους. Συνδεθείτε ξανά.',
        'weight.recorded.title': 'Το βάρος καταγράφηκε',
        'weight.recorded.msg': 'Το βάρος σας καταγράφηκε με επιτυχία.',
        'weight.record_failed.msg': 'Αποτυχία καταγραφής βάρους. Προσπαθήστε ξανά.'
    },
    'tr': {
        'weight.record.title': 'Kilo kaydı',
        'weight.take_photo': 'Fotoğraf çek',
        'weight.manual_entry': 'Manuel giriş',
        'weight.record.msg': 'Kilonuzu nasıl kaydetmek istediğinizi seçin',
        'weight.enter.title': 'Kilo girin',
        'weight.enter.placeholder': 'Kilo (kg)',
        'weight.enter.msg': 'Kilonuzu kilogram cinsinden girin',
        'weight.invalid.title': 'Geçersiz kilo',
        'weight.invalid.msg': 'Lütfen kilonuzu kilogram olarak geçerli girin.',
        'weight.need_login': 'Kilo gönderilemiyor. Lütfen tekrar giriş yapın.',
        'weight.recorded.title': 'Kilo kaydedildi',
        'weight.recorded.msg': 'Kilonuz başarıyla kaydedildi.',
        'weight.record_failed.msg': 'Kilo kaydı başarısız. Tekrar deneyin.'
    },
    'ar': {
        'weight.record.title': 'تسجيل الوزن',
        'weight.take_photo': 'التقاط صورة',
        'weight.manual_entry': 'إدخال يدوي',
        'weight.record.msg': 'اختر كيف تريد تسجيل وزنك',
        'weight.enter.title': 'أدخل الوزن',
        'weight.enter.placeholder': 'الوزن (كغ)',
        'weight.enter.msg': 'أدخل وزنك بالكيلوغرام',
        'weight.invalid.title': 'وزن غير صالح',
        'weight.invalid.msg': 'يرجى إدخال وزن صالح بالكيلوغرام.',
        'weight.need_login': 'لا يمكن إرسال الوزن. يرجى تسجيل الدخول مرة أخرى.',
        'weight.recorded.title': 'تم تسجيل الوزن',
        'weight.recorded.msg': 'تم تسجيل وزنك بنجاح.',
        'weight.record_failed.msg': 'فشل تسجيل وزنك. حاول مرة أخرى.'
    },
    'ur': {
        'weight.record.title': 'وزن ریکارڈ کریں',
        'weight.take_photo': 'تصویر لیں',
        'weight.manual_entry': 'دستی اندراج',
        'weight.record.msg': 'منتخب کریں آپ اپنا وزن کیسے ریکارڈ کرنا چاہتے ہیں',
        'weight.enter.title': 'وزن درج کریں',
        'weight.enter.placeholder': 'وزن (کلو)',
        'weight.enter.msg': 'اپنا وزن کلوگرام میں درج کریں',
        'weight.invalid.title': 'غلط وزن',
        'weight.invalid.msg': 'براہ کرم کلوگرام میں درست وزن درج کریں۔',
        'weight.need_login': 'وزن جمع کرنا ممکن نہیں۔ دوبارہ سائن ان کریں۔',
        'weight.recorded.title': 'وزن ریکارڈ ہو گیا',
        'weight.recorded.msg': 'آپ کا وزن کامیابی سے ریکارڈ ہو گیا۔',
        'weight.record_failed.msg': 'وزن ریکارڈ کرنے میں ناکامی۔ دوبارہ کوشش کریں۔'
    },
    'hi': {
        'weight.record.title': 'वजन रिकॉर्ड करें',
        'weight.take_photo': 'फोटो लें',
        'weight.manual_entry': 'मैन्युअल प्रविष्टि',
        'weight.record.msg': 'चुनें कि आप अपना वजन कैसे रिकॉर्ड करना चाहते हैं',
        'weight.enter.title': 'वजन दर्ज करें',
        'weight.enter.placeholder': 'वजन (किग्रा)',
        'weight.enter.msg': 'अपना वजन किलोग्राम में दर्ज करें',
        'weight.invalid.title': 'अमान्य वजन',
        'weight.invalid.msg': 'कृपया किलोग्राम में वैध वजन दर्ज करें।',
        'weight.need_login': 'वजन सबमिट नहीं कर सकते। कृपया फिर से साइन इन करें।',
        'weight.recorded.title': 'वजन रिकॉर्ड हुआ',
        'weight.recorded.msg': 'आपका वजन सफलतापूर्वक रिकॉर्ड हो गया है।',
        'weight.record_failed.msg': 'वजन रिकॉर्ड करने में विफल। कृपया फिर से प्रयास करें।'
    },
    'bn': {
        'weight.record.title': 'ওজন রেকর্ড করুন',
        'weight.take_photo': 'ছবি তুলুন',
        'weight.manual_entry': 'ম্যানুয়াল এন্ট্রি',
        'weight.record.msg': 'আপনি কীভাবে আপনার ওজন রেকর্ড করতে চান তা চয়ন করুন',
        'weight.enter.title': 'ওজন লিখুন',
        'weight.enter.placeholder': 'ওজন (কেজি)',
        'weight.enter.msg': 'আপনার ওজন কিলোগ্রামে লিখুন',
        'weight.invalid.title': 'অবৈধ ওজন',
        'weight.invalid.msg': 'দয়া করে কিলোগ্রামে বৈধ ওজন লিখুন।',
        'weight.need_login': 'ওজন জমা দেওয়া যাবে না। আবার সাইন ইন করুন।',
        'weight.recorded.title': 'ওজন রেকর্ড হয়েছে',
        'weight.recorded.msg': 'আপনার ওজন সফলভাবে রেকর্ড করা হয়েছে।',
        'weight.record_failed.msg': 'ওজন রেকর্ড করতে ব্যর্থ হয়েছে। আবার চেষ্টা করুন।'
    },
    'th': {
        'weight.record.title': 'บันทึกน้ำหนัก',
        'weight.take_photo': 'ถ่ายรูป',
        'weight.manual_entry': 'ป้อนข้อมูลด้วยตนเอง',
        'weight.record.msg': 'เลือกวิธีที่คุณต้องการบันทึกน้ำหนัก',
        'weight.enter.title': 'กรอกน้ำหนัก',
        'weight.enter.placeholder': 'น้ำหนัก (กก.)',
        'weight.enter.msg': 'กรอกน้ำหนักของคุณเป็นกิโลกรัม',
        'weight.invalid.title': 'น้ำหนักไม่ถูกต้อง',
        'weight.invalid.msg': 'กรุณากรอกน้ำหนักที่ถูกต้องเป็นกิโลกรัม',
        'weight.need_login': 'ไม่สามารถส่งน้ำหนักได้ กรุณาเข้าสู่ระบบอีกครั้ง',
        'weight.recorded.title': 'บันทึกน้ำหนักแล้ว',
        'weight.recorded.msg': 'บันทึกน้ำหนักของคุณเรียบร้อยแล้ว',
        'weight.record_failed.msg': 'ไม่สามารถบันทึกน้ำหนักได้ โปรดลองอีกครั้ง'
    },
    'vi': {
        'weight.record.title': 'Ghi lại cân nặng',
        'weight.take_photo': 'Chụp ảnh',
        'weight.manual_entry': 'Nhập thủ công',
        'weight.record.msg': 'Chọn cách bạn muốn ghi lại cân nặng của mình',
        'weight.enter.title': 'Nhập cân nặng',
        'weight.enter.placeholder': 'Cân nặng (kg)',
        'weight.enter.msg': 'Nhập cân nặng của bạn bằng kilogram',
        'weight.invalid.title': 'Cân nặng không hợp lệ',
        'weight.invalid.msg': 'Vui lòng nhập cân nặng hợp lệ bằng kilogram.',
        'weight.need_login': 'Không thể gửi cân nặng. Vui lòng đăng nhập lại.',
        'weight.recorded.title': 'Đã ghi cân nặng',
        'weight.recorded.msg': 'Cân nặng của bạn đã được ghi thành công.',
        'weight.record_failed.msg': 'Ghi cân nặng thất bại. Vui lòng thử lại.'
    },
    'ja': {
        'weight.record.title': '体重を記録',
        'weight.take_photo': '写真を撮る',
        'weight.manual_entry': '手動入力',
        'weight.record.msg': '体重を記録する方法を選択してください',
        'weight.enter.title': '体重を入力',
        'weight.enter.placeholder': '体重 (kg)',
        'weight.enter.msg': '体重をキログラムで入力してください',
        'weight.invalid.title': '無効な体重',
        'weight.invalid.msg': '有効な体重をキログラムで入力してください。',
        'weight.need_login': '体重を送信できません。再度サインインしてください。',
        'weight.recorded.title': '体重を記録しました',
        'weight.recorded.msg': '体重が正常に記録されました。',
        'weight.record_failed.msg': '体重の記録に失敗しました。もう一度お試しください。'
    },
    'ko': {
        'weight.record.title': '체중 기록',
        'weight.take_photo': '사진 촬영',
        'weight.manual_entry': '직접 입력',
        'weight.record.msg': '체중을 기록할 방법을 선택하세요',
        'weight.enter.title': '체중 입력',
        'weight.enter.placeholder': '체중 (kg)',
        'weight.enter.msg': '체중을 킬로그램으로 입력하세요',
        'weight.invalid.title': '잘못된 체중',
        'weight.invalid.msg': '유효한 체중을 킬로그램으로 입력하세요.',
        'weight.need_login': '체중을 전송할 수 없습니다. 다시 로그인하세요.',
        'weight.recorded.title': '체중 기록됨',
        'weight.recorded.msg': '체중이 성공적으로 기록되었습니다.',
        'weight.record_failed.msg': '체중 기록에 실패했습니다. 다시 시도하세요.'
    },
    'zh': {
        'weight.record.title': '记录体重',
        'weight.take_photo': '拍照',
        'weight.manual_entry': '手动输入',
        'weight.record.msg': '选择如何记录你的体重',
        'weight.enter.title': '输入体重',
        'weight.enter.placeholder': '体重 (kg)',
        'weight.enter.msg': '请输入你的体重（千克）',
        'weight.invalid.title': '无效的体重',
        'weight.invalid.msg': '请输入有效的体重（千克）。',
        'weight.need_login': '无法提交体重。请重新登录。',
        'weight.recorded.title': '体重已记录',
        'weight.recorded.msg': '你的体重已成功记录。',
        'weight.record_failed.msg': '记录体重失败。请重试。'
    },
    'et': {
        'weight.record.title': 'Salvesta kaal',
        'weight.take_photo': 'Tee foto',
        'weight.manual_entry': 'Käsitsi sisestus',
        'weight.record.msg': 'Valige, kuidas soovite oma kaalu salvestada',
        'weight.enter.title': 'Sisesta kaal',
        'weight.enter.placeholder': 'Kaal (kg)',
        'weight.enter.msg': 'Sisestage oma kaal kilogrammides',
        'weight.invalid.title': 'Vigane kaal',
        'weight.invalid.msg': 'Sisestage kehtiv kaal kilogrammides.',
        'weight.need_login': 'Kaalu ei saa saata. Logige uuesti sisse.',
        'weight.recorded.title': 'Kaal salvestatud',
        'weight.recorded.msg': 'Teie kaal on edukalt salvestatud.',
        'weight.record_failed.msg': 'Kaalu salvestamine ebaõnnestus. Proovige uuesti.'
    },
    'lv': {
        'weight.record.title': 'Reģistrēt svaru',
        'weight.take_photo': 'Uzņemt foto',
        'weight.manual_entry': 'Manuāla ievade',
        'weight.record.msg': 'Izvēlieties, kā reģistrēt savu svaru',
        'weight.enter.title': 'Ievadīt svaru',
        'weight.enter.placeholder': 'Svars (kg)',
        'weight.enter.msg': 'Ievadiet savu svaru kilogramos',
        'weight.invalid.title': 'Nederīgs svars',
        'weight.invalid.msg': 'Lūdzu, ievadiet derīgu svaru kilogramos.',
        'weight.need_login': 'Nevar iesniegt svaru. Lūdzu, piesakieties vēlreiz.',
        'weight.recorded.title': 'Svars reģistrēts',
        'weight.recorded.msg': 'Jūsu svars ir veiksmīgi reģistrēts.',
        'weight.record_failed.msg': 'Svara reģistrācija neizdevās. Mēģiniet vēlreiz.'
    },
    'lt': {
        'weight.record.title': 'Įrašyti svorį',
        'weight.take_photo': 'Nufotografuoti',
        'weight.manual_entry': 'Rankinis įvedimas',
        'weight.record.msg': 'Pasirinkite, kaip norite įrašyti savo svorį',
        'weight.enter.title': 'Įveskite svorį',
        'weight.enter.placeholder': 'Svoris (kg)',
        'weight.enter.msg': 'Įveskite savo svorį kilogramais',
        'weight.invalid.title': 'Neteisingas svoris',
        'weight.invalid.msg': 'Įveskite teisingą svorį kilogramais.',
        'weight.need_login': 'Nepavyko pateikti svorio. Prisijunkite iš naujo.',
        'weight.recorded.title': 'Svoris įrašytas',
        'weight.recorded.msg': 'Jūsų svoris sėkmingai įrašytas.',
        'weight.record_failed.msg': 'Nepavyko įrašyti svorio. Bandykite dar kartą.'
    },
    'mt': {
        'weight.record.title': 'Irreġistra l-piż',
        'weight.take_photo': 'Ħu ritratt',
        'weight.manual_entry': 'Dħul manwali',
        'weight.record.msg': 'Agħżel kif trid tirreġistra l-piż tiegħek',
        'weight.enter.title': 'Daħħal il-piż',
        'weight.enter.placeholder': 'Piż (kg)',
        'weight.enter.msg': 'Daħħal il-piż tiegħek f’kilogrammi',
        'weight.invalid.title': 'Piż invalidu',
        'weight.invalid.msg': 'Daħħal piż validu f’kilogrammi.',
        'weight.need_login': 'Ma tistax tissottometti l-piż. Erġa’ idħol.',
        'weight.recorded.title': 'Il-piż irreġistrat',
        'weight.recorded.msg': 'Il-piż tiegħek ġie rreġistrat b’suċċess.',
        'weight.record_failed.msg': 'Ir-reġistrazzjoni tal-piż falliet. Erġa’ pprova.'
    },
    'ga': {
        'weight.record.title': 'Taifead Meáchain',
        'weight.take_photo': 'Tóg grianghraf',
        'weight.manual_entry': 'Iontráil láimhe',
        'weight.record.msg': 'Roghnaigh conas ba mhaith leat do mheáchan a thaifeadadh',
        'weight.enter.title': 'Cuir isteach meáchan',
        'weight.enter.placeholder': 'Meáchan (kg)',
        'weight.enter.msg': 'Cuir isteach do mheáchan i gciligram',
        'weight.invalid.title': 'Meáchan neamhbhailí',
        'weight.invalid.msg': 'Cuir isteach meáchan bailí i gciligram.',
        'weight.need_login': 'Ní féidir meáchan a chur isteach. Sínigh isteach arís.',
        'weight.recorded.title': 'Meáchan taifeadta',
        'weight.recorded.msg': 'Taifeadadh do mheáchan go rathúil.',
        'weight.record_failed.msg': 'Theip ar thaifeadadh meáchain. Déan iarracht arís.'
    },
    'hr': {
        'weight.record.title': 'Zabilježi težinu',
        'weight.take_photo': 'Fotografiraj',
        'weight.manual_entry': 'Ručni unos',
        'weight.record.msg': 'Odaberite način bilježenja težine',
        'weight.enter.title': 'Unesite težinu',
        'weight.enter.placeholder': 'Težina (kg)',
        'weight.enter.msg': 'Unesite težinu u kilogramima',
        'weight.invalid.title': 'Nevažeća težina',
        'weight.invalid.msg': 'Unesite važeću težinu u kilogramima.',
        'weight.need_login': 'Nije moguće poslati težinu. Prijavite se ponovno.',
        'weight.recorded.title': 'Težina zabilježena',
        'weight.recorded.msg': 'Vaša težina je uspješno zabilježena.',
        'weight.record_failed.msg': 'Zabilježavanje težine nije uspjelo. Pokušajte ponovno.'
    },
    'hu': {
        'weight.record.title': 'Testsúly rögzítése',
        'weight.take_photo': 'Fénykép készítése',
        'weight.manual_entry': 'Kézi bevitel',
        'weight.record.msg': 'Válassza ki, hogyan szeretné rögzíteni a testsúlyát',
        'weight.enter.title': 'Testsúly megadása',
        'weight.enter.placeholder': 'Testsúly (kg)',
        'weight.enter.msg': 'Adja meg a testsúlyát kilogrammban',
        'weight.invalid.title': 'Érvénytelen testsúly',
        'weight.invalid.msg': 'Kérjük, érvényes testsúlyt adjon meg kilogrammban.',
        'weight.need_login': 'A testsúly nem küldhető el. Kérjük, jelentkezzen be újra.',
        'weight.recorded.title': 'Testsúly rögzítve',
        'weight.recorded.msg': 'Testsúlyát sikeresen rögzítettük.',
        'weight.record_failed.msg': 'A testsúly rögzítése nem sikerült. Próbálja újra.'
    },
}


def update_file(path: str, code: str) -> bool:
    try:
        with open(path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception as e:
        print(f"Skip {path}: {e}")
        return False
    trans = WEIGHT.get(code, WEIGHT['en'])
    changed = False
    for k in WEIGHT_KEYS:
        v = trans.get(k, WEIGHT['en'][k])
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
