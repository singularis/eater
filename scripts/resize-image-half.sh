#!/usr/bin/env bash
# Resize image to half dimensions (width and height). Overwrites the file.
# Usage: ./resize-image-half.sh <path-to-image>
# Example: ./resize-image-half.sh Assets.xcassets/stats_dog_gym.imageset/stats_dog_gym.png

set -e
if [ $# -lt 1 ]; then
  echo "Usage: $0 <image-path>"
  exit 1
fi
IMG="$1"
if [ ! -f "$IMG" ]; then
  echo "File not found: $IMG"
  exit 1
fi
W=$(sips -g pixelWidth "$IMG" | awk '/pixelWidth:/ {print $2}')
H=$(sips -g pixelHeight "$IMG" | awk '/pixelHeight:/ {print $2}')
NW=$((W / 2))
NH=$((H / 2))
echo "Resizing $IMG from ${W}x${H} to ${NW}x${NH}"
sips -z "$NH" "$NW" "$IMG"
echo "Done."
