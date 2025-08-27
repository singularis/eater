#!/usr/bin/env python3
import json
import glob
import os

ROOT = "/Users/dante/Documents/dante/Documents/eater/eater/Localization"

# Three-character (or local-script) abbreviations per language
PRO = {
    'ar':'برو','be':'БЯЛ','bg':'БЕЛ','bn':'PRO','cs':'BIL','da':'PRO','de':'EIW','el':'ΠΡΩ','en':'PRO','es':'PRO',
    'et':'PRO','fi':'PRO','fr':'PRO','ga':'PRO','hi':'PRO','hr':'PRO','hu':'FEH','it':'PRO','ja':'PRO','ko':'PRO',
    'lt':'BAL','lv':'OLB','mt':'PRO','nl':'EIW','pl':'BIA','pt':'PRO','ro':'PRO','sk':'BIE','sl':'BEL','sv':'PRO',
    'th':'PRO','tr':'PRO','uk':'БІЛ','ur':'PRO','vi':'PRO','zh':'PRO'
}
FAT = {
    'ar':'دهو','be':'ТЛУ','bg':'МАЗ','bn':'FAT','cs':'TUK','da':'FED','de':'FET','el':'ΛΙΠ','en':'FAT','es':'GRA',
    'et':'RAS','fi':'RAS','fr':'LIP','ga':'SAI','hi':'FAT','hr':'MAS','hu':'ZSI','it':'GRS','ja':'FAT','ko':'FAT',
    'lt':'RIE','lv':'TAU','mt':'XAĦ','nl':'VET','pl':'TŁU','pt':'GRA','ro':'GRA','sk':'TUK','sl':'MAŠ','sv':'FET',
    'th':'FAT','tr':'YAĞ','uk':'ЖИР','ur':'FAT','vi':'BÉO','zh':'FAT'
}
CAR = {
    'ar':'كرب','be':'ВУГ','bg':'ВЪГ','bn':'CAR','cs':'SAC','da':'KUL','de':'KOH','el':'ΥΔΑ','en':'CAR','es':'CAR',
    'et':'SÜS','fi':'HII','fr':'GLU','ga':'CAR','hi':'CAR','hr':'UGL','hu':'SZÉ','it':'CAR','ja':'CAR','ko':'CAR',
    'lt':'ANG','lv':'OGL','mt':'KAR','nl':'KOO','pl':'WEG','pt':'CAR','ro':'CAR','sk':'SAC','sl':'OGL','sv':'KOL',
    'th':'CAR','tr':'KAR','uk':'ВУГ','ur':'CAR','vi':'CAR','zh':'CAR'
}
SUG = {
    'ar':'سكر','be':'ЦУК','bg':'ЗАХ','bn':'SUG','cs':'CUK','da':'SUK','de':'ZUC','el':'ΣΑΚ','en':'SUG','es':'AZU',
    'et':'SUH','fi':'SOK','fr':'SUC','ga':'SIÚ','hi':'SUG','hr':'ŠEĆ','hu':'CUK','it':'ZUC','ja':'SUG','ko':'SUG',
    'lt':'CUK','lv':'CUK','mt':'ZOK','nl':'SUI','pl':'CUK','pt':'AÇU','ro':'ZAH','sk':'CUK','sl':'SLA','sv':'SOC',
    'th':'SUG','tr':'ŞEK','uk':'ЦУК','ur':'SUG','vi':'SUG','zh':'SUG'
}

def write_file(path: str, data: dict) -> None:
    with open(path, 'w', encoding='utf-8') as fh:
        json.dump(data, fh, ensure_ascii=False, indent=2, sort_keys=True)

def main() -> None:
    files = sorted(glob.glob(os.path.join(ROOT, '*.json')))
    changed = 0
    for f in files:
        code = os.path.splitext(os.path.basename(f))[0].lower()
        try:
            with open(f, 'r', encoding='utf-8') as fh:
                data = json.load(fh)
        except Exception as e:
            print('SKIP', f, e)
            continue

        upd = False
        pro = PRO.get(code, data.get('macro.pro', 'PRO'))
        fat = FAT.get(code, data.get('macro.fat', 'FAT'))
        car = CAR.get(code, data.get('macro.car', 'CAR'))
        sug = SUG.get(code, data.get('macro.sug', 'SUG'))

        if data.get('macro.pro') != pro:
            data['macro.pro'] = pro; upd = True
        if data.get('macro.fat') != fat:
            data['macro.fat'] = fat; upd = True
        if data.get('macro.car') != car:
            data['macro.car'] = car; upd = True
        if data.get('macro.sug') != sug:
            data['macro.sug'] = sug; upd = True

        if upd:
            write_file(f, data)
            changed += 1
            print('UPDATED', os.path.basename(f), pro, fat, car, sug)
    print('DONE', changed)

if __name__ == '__main__':
    main()


