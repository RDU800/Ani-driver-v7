#!/usr/bin/env bash
set -euo pipefail

DEST_DIR="${1:-build/mesa}"
LOCK_FILE="$(cd "$(dirname "$0")/.." && pwd)/sources.lock"

# shellcheck disable=SC1090
source "$LOCK_FILE"

mkdir -p "$DEST_DIR"

if [ ! -d "$DEST_DIR/.git" ]; then
  echo ">>> Initializing Mesa repo in $DEST_DIR"
  git -C "$DEST_DIR" init -q
  git -C "$DEST_DIR" remote add origin "$MESA_REPO"
fi

echo ">>> Fetching $MESA_COMMIT from $MESA_REPO"
if ! git -C "$DEST_DIR" fetch --depth 1 origin "$MESA_COMMIT" 2>/dev/null; then
  echo ">>> Direct SHA fetch not advertised; fetching shallow main branch and deepening..."
  git -C "$DEST_DIR" fetch --depth 50 origin main
  DEPTH=50
  while ! git -C "$DEST_DIR" cat-file -e "${MESA_COMMIT}^{commit}" 2>/dev/null; do
    DEPTH=$((DEPTH + 100))
    echo ">>> Deepening fetch to depth $DEPTH..."
    git -C "$DEST_DIR" fetch --depth="$DEPTH" origin main
    if [ "$DEPTH" -ge 1050 ]; then
      echo ">>> Falling back to full fetch of main..."
      git -C "$DEST_DIR" fetch origin main
      break
    fi
  done
fi

git -C "$DEST_DIR" checkout --detach "$MESA_COMMIT"
echo ">>> Checked out Mesa commit $MESA_COMMIT"
