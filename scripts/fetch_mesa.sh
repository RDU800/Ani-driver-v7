#!/usr/bin/env bash
set -euo pipefail

DEST_DIR="${1:-build/mesa}"
LOCK_FILE="$(cd "$(dirname "$0")/.." && pwd)/sources.lock"

# shellcheck disable=SC1090
source "$LOCK_FILE"

rm -rf "$DEST_DIR"
mkdir -p "$DEST_DIR"

echo ">>> Initializing blobless clone of $MESA_REPO into $DEST_DIR"
git -C "$DEST_DIR" init -q
git -C "$DEST_DIR" remote add origin "$MESA_REPO"

echo ">>> Fetching commit $MESA_COMMIT (blobless)"
if ! git -C "$DEST_DIR" fetch --filter=blob:none origin "$MESA_COMMIT" 2>/dev/null; then
  echo ">>> Direct SHA fetch not allowed; fetching blobless main history..."
  git -C "$DEST_DIR" fetch --filter=blob:none origin main
fi

git -C "$DEST_DIR" -c advice.detachedHead=false checkout "$MESA_COMMIT"
echo ">>> Checked out Mesa commit $MESA_COMMIT"
