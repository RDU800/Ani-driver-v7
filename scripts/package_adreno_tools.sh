#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="${1:-$ROOT_DIR/build/out}"
DIST_DIR="${2:-$ROOT_DIR/dist}"

# shellcheck disable=SC1090
source "$ROOT_DIR/sources.lock"

SO_FILE="$OUT_DIR/libvulkan_panfrost.so"
if [ ! -f "$SO_FILE" ]; then
  echo "Error: Missing $SO_FILE" >&2
  find "$OUT_DIR" -maxdepth 4 -name "libvulkan*.so" 2>/dev/null || true
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
ZIP_PATH="$DIST_DIR/$ZIP_NAME"

if command -v zip >/dev/null 2>&1; then
  (
    cd "$STAGE_DIR"
    zip -qr "$ZIP_PATH" .
  )
else
  python3 -c '
import os, sys, zipfile
src_dir, out_zip = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(out_zip, "w", compression=zipfile.ZIP_DEFLATED) as zf:
    for root, _, files in os.walk(src_dir):
        for f in files:
            full = os.path.join(root, f)
            rel = os.path.relpath(full, src_dir)
            zf.write(full, rel)
' "$STAGE_DIR" "$ZIP_PATH"
fi

(
  cd "$DIST_DIR"
  sha256sum "$ZIP_NAME" > SHA256SUMS.txt
)

echo ">>> Packaged $ZIP_PATH"
