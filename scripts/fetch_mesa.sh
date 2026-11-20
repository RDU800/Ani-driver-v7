#!/usr/bin/env bash
set -euo pipefail

DEST_DIR="${1:-build/mesa}"
LOCK_FILE="$(cd "$(dirname "$0")/.." && pwd)/sources.lock"

# shellcheck disable=SC1090
source "$LOCK_FILE"

if [ -d "$DEST_DIR/.git" ]; then
  echo ">>> Updating existing Mesa checkout in $DEST_DIR"
  git -C "$DEST_DIR" fetch --depth 1 origin "$MESA_COMMIT"
  git -C "$DEST_DIR" checkout --detach FETCH_HEAD
else
  echo ">>> Cloning $MESA_REPO at $MESA_COMMIT into $DEST_DIR"
  mkdir -p "$DEST_DIR"
  git -C "$DEST_DIR" init -q
  git -C "$DEST_DIR" remote add origin "$MESA_REPO"
  git -C "$DEST_DIR" fetch --depth 1 origin "$MESA_COMMIT"
  git -C "$DEST_DIR" checkout --detach FETCH_HEAD
fi
