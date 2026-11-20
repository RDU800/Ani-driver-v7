#!/usr/bin/env bash
set -euo pipefail

MESA_DIR="${1:?Usage: apply_patches.sh <mesa_dir>}"
PATCH_ROOT="$(cd "$(dirname "$0")/.." && pwd)/patches"

if [ ! -d "$PATCH_ROOT" ]; then
  echo ">>> No patches directory at $PATCH_ROOT; skipping patch step"
  exit 0
fi

cd "$MESA_DIR"
git config user.name "ani-panvk-ci"
git config user.email "ci@local"

applied=0
for layer in "$PATCH_ROOT"/*; do
  [ -d "$layer" ] || continue
  for patch in "$layer"/*.patch; do
    [ -f "$patch" ] || continue
    echo ">>> Applying $(basename "$layer")/$(basename "$patch")"
    git am --3way "$patch"
    applied=$((applied + 1))
  done
done

echo ">>> Applied $applied patch(es)"
