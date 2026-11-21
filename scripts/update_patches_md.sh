#!/usr/bin/env bash
set -euo pipefail

PATCH_DIR="${1:-patches}"
OUT_FILE="${2:-PATCHES.md}"
NOW_UTC="$(date -u +'%Y-%m-%d %H:%M:%S UTC')"

if [ ! -f "$OUT_FILE" ]; then
  {
    echo "# Ani-Driver Applied Patches"
    echo ""
    echo "| Date & Time (UTC) | Patches Included |"
    echo "| :--- | :--- |"
  } > "$OUT_FILE"
fi

if [ -d "$PATCH_DIR" ] && compgen -G "$PATCH_DIR/*.patch" > /dev/null; then
  LIST="$(ls -1 "$PATCH_DIR"/*.patch | xargs -n1 basename | paste -sd ', ' -)"
else
  LIST="none"
fi

echo "| ${NOW_UTC} | ${LIST} |" >> "$OUT_FILE"
echo "Updated $OUT_FILE ($NOW_UTC): $LIST"
