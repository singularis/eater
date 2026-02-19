#!/usr/bin/env bash
# Встановити фото кота для котячої теми (центр планет у статистиці).
# Usage: ./set-cat-gym-image.sh <шлях-до-зображення.png>
# Example: ./set-cat-gym-image.sh ~/Downloads/cat_gym.png
# Потім зображення зменшується вдвічі скриптом resize-image-half.sh.

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EATER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ASSETS="$EATER_DIR/eater/Assets.xcassets/stats_cat_gym.imageset"
DEST="$(cd "$ASSETS" && pwd)/stats_cat_gym.png"

if [ $# -lt 1 ]; then
  echo "Usage: $0 <path-to-image.png>"
  echo "Example: $0 ~/Downloads/cat_dumbbell.png"
  exit 1
fi
SRC="$1"
if [ ! -f "$SRC" ]; then
  echo "File not found: $SRC"
  exit 1
fi

cp "$SRC" "$DEST"
echo "Copied to $DEST"
"$SCRIPT_DIR/resize-image-half.sh" "$DEST"
echo "Cat gym image updated."
