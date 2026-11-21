#!/usr/bin/env bash
set -euo pipefail

MESA_DIR="${1:?Usage: apply_patches.sh <mesa_dir>}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PATCH_ROOT="$REPO_ROOT/patches"
PATCHES_MD="$REPO_ROOT/PATCHES.md"

if [ ! -d "$PATCH_ROOT" ]; then
  echo ">>> No patches directory at $PATCH_ROOT; skipping patch step"
  exit 0
fi

cd "$MESA_DIR"
git config user.name "ani-panvk-ci"
git config user.email "ci@local"

applied=0
applied_list=""
for layer in "$PATCH_ROOT"/*; do
  [ -d "$layer" ] || continue
  for patch in "$layer"/*.patch; do
    [ -f "$patch" ] || continue
    echo ">>> Applying $(basename "$layer")/$(basename "$patch")"
    git am --3way "$patch"
    applied=$((applied + 1))
    entry="$(basename "$layer")/$(basename "$patch")"
    applied_list="${applied_list:+$applied_list, }$entry"
  done
done

echo ">>> Applied $applied patch(es)"

[ -f "$PATCHES_MD" ] || printf "# Applied Patches\n\n| Date & Time (UTC) | Patches |\n| :--- | :--- |\n" > "$PATCHES_MD"
printf "| %s | %s |\n" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')" "${applied_list:-none}" >> "$PATCHES_MD"
