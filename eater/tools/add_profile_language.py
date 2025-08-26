import os
import re

LOCALIZATION_DIR = "/Users/dante/Documents/dante/Documents/eater/eater/Localization"

# Mapping: language code -> translation for the noun "Language"
LANGUAGE_WORD = {
    "en": "Language",
    "ar": "اللغة",
    "be": "Мова",
    "bg": "Език",
    "bn": "ভাষা",
    "cs": "Jazyk",
    "da": "Sprog",
    "de": "Sprache",
    "el": "Γλώσσα",
    "es": "Idioma",
    "et": "Keel",
    "fi": "Kieli",
    "fr": "Langue",
    "ga": "Teanga",
    "hi": "भाषा",
    "hr": "Jezik",
    "hu": "Nyelv",
    "it": "Lingua",
    "ja": "言語",
    "ko": "언어",
    "lt": "Kalba",
    "lv": "Valoda",
    "mt": "Lingwa",
    "nl": "Taal",
    "pl": "Język",
    "pt": "Idioma",
    "ro": "Limbă",
    "sk": "Jazyk",
    "sl": "Jezik",
    "sv": "Språk",
    "th": "ภาษา",
    "tr": "Dil",
    "uk": "Мова",
    "ur": "زبان",
    "vi": "Ngôn ngữ",
    "zh": "语言",
}


def add_profile_language_to_file(json_path: str, code: str, translation: str) -> str:
    """Insert a new line with "profile.language": "<translation>", after the profile.tutorial line.

    Preserves file indentation and minimizes changes by editing text instead of reformatting JSON.
    Returns a status string.
    """
    try:
        with open(json_path, "r", encoding="utf-8") as f:
            lines = f.readlines()
    except Exception as e:
        return f"ERROR reading {os.path.basename(json_path)}: {e}"

    # Skip if key already present
    if any('"profile.language"' in line for line in lines):
        return f"SKIP {code}.json (already present)"

    # Find anchor: the profile.tutorial key
    anchor_index = None
    for i, line in enumerate(lines):
        if '"profile.tutorial"' in line:
            anchor_index = i
            break
    if anchor_index is None:
        return f"SKIP {code}.json (anchor 'profile.tutorial' not found)"

    # Determine indentation from the anchor line
    m = re.match(r"^(\s*)", lines[anchor_index])
    indent = m.group(1) if m else "  "

    new_line = f"{indent}\"profile.language\": \"{translation}\",\n"

    # Insert after the anchor line
    lines.insert(anchor_index + 1, new_line)

    try:
        with open(json_path, "w", encoding="utf-8") as f:
            f.writelines(lines)
    except Exception as e:
        return f"ERROR writing {os.path.basename(json_path)}: {e}"

    return f"ADDED {code}.json"


def main():
    if not os.path.isdir(LOCALIZATION_DIR):
        print(f"ERROR: Directory not found: {LOCALIZATION_DIR}")
        return

    files = [f for f in os.listdir(LOCALIZATION_DIR) if f.endswith('.json')]
    files.sort()

    for filename in files:
        code = os.path.splitext(filename)[0]
        if code not in LANGUAGE_WORD:
            print(f"SKIP {filename} (no mapping for code '{code}')")
            continue
        translation = LANGUAGE_WORD[code]
        path = os.path.join(LOCALIZATION_DIR, filename)
        result = add_profile_language_to_file(path, code, translation)
        print(result)


if __name__ == "__main__":
    main()


