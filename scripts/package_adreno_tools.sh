#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-build/out}"
DIST_DIR="${2:-dist}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# shellcheck disable=SC1090
source "$ROOT_DIR/sources.lock"

SO_FILE="$OUT_DIR/libvulkan_panfrost.so"
if [ ! -f "$SO_FILE" ]; then
  echo "Error: Missing $SO_FILE" >&2
  exit 1
fi

STAGE_DIR="$OUT_DIR/package"
rm -rf "$STAGE_DIR" "$DIST_DIR"
mkdir -p "$STAGE_DIR" "$DIST_DIR"

cp "$SO_FILE" "$STAGE_DIR/libvulkan_panfrost.so"

cat > "$STAGE_DIR/meta.json" <<EOF
{
  "schemaVersion": 1,
  "name": "${DRIVER_NAME}",
  "driverVersion": "${DRIVER_VERSION}",
  "mesaCommit": "${MESA_COMMIT}",
  "libraryName": "libvulkan_panfrost.so"
}
EOF

ZIP_NAME="${DRIVER_NAME}-${DRIVER_VERSION}-android-aarch64.zip"
(
  cd "$STAGE_DIR"
  zip -qr "$ROOT_DIR/$DIST_DIR/$ZIP_NAME" .
)

(
  cd "$DIST_DIR"
  sha256sum "$ZIP_NAME" > SHA256SUMS.txt
)

echo ">>> Packaged $DIST_DIR/$ZIP_NAME"
