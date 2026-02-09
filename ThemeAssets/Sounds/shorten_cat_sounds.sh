#!/bin/bash
# Скорочує cat_happy.m4a та cat_hiss.m4a вдвічі (перша половина запису).
# Потрібен ffmpeg: brew install ffmpeg

set -e
SOUNDS_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SOUNDS_DIR"

if ! command -v ffmpeg &>/dev/null; then
  echo "Потрібен ffmpeg. Встановіть: brew install ffmpeg"
  exit 1
fi

for name in cat_happy cat_hiss; do
  src="${name}.m4a"
  tmp="${name}_short.m4a"
  [ ! -f "$src" ] && echo "Пропуск: $src не знайдено" && continue
  dur=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$src" 2>/dev/null)
  half=$(python3 -c "print($dur/2)")
  echo " $src: ${dur}s -> ${half}s"
  ffmpeg -y -i "$src" -t "$half" -c copy "$tmp" -loglevel error
  mv "$tmp" "$src"
done
echo "Готово."
