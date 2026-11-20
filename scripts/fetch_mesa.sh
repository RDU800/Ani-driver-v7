#!/usr/bin/env bash
set -euo pipefail

DEST_DIR="${1:-build/mesa}"
LOCK_FILE="$(cd "$(dirname "$0")/.." && pwd)/sources.lock"

# shellcheck disable=SC1090
source "$LOCK_FILE"

REF="${MESA_REF:-${MESA_COMMIT:-main}}"

rm -rf "$DEST_DIR"
mkdir -p "$DEST_DIR"

echo ">>> Cloning $MESA_REPO ($REF) into $DEST_DIR"
git -C "$DEST_DIR" init -q
git -C "$DEST_DIR" remote add origin "$MESA_REPO"
git -C "$DEST_DIR" fetch --depth 1 origin "$REF"
git -C "$DEST_DIR" -c advice.detachedHead=false checkout FETCH_HEAD
echo ">>> Checked out Mesa ref: $REF ($(git -C "$DEST_DIR" rev-parse --short HEAD))"
