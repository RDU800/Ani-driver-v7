#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Resolve to absolute paths (relative ones break after `cd` below)
OUT_DIR="$(realpath -m "${1:-$ROOT_DIR/build/out}")"
DIST_DIR="$(realpath -m "${2:-$ROOT_DIR/dist}")"

# shellcheck disable=SC1090
source "$ROOT_DIR/sources.lock"

LIB_NAME="libvulkan_panfrost.so"
STAGE_DIR="$OUT_DIR/package"

# Locate the .so. Search the staged output first, then the Meson build dir,
# because a relative --prefix can land under build/android-arm64/build/out.
find_lib() {
  local dir
  for dir in "$OUT_DIR" "$ROOT_DIR/build/android-arm64/build/out" "$ROOT_DIR/build/android-arm64"; do
    [ -d "$dir" ] || continue
    local hit
    hit="$(find "$dir" -type f -name "$LIB_NAME" -not -path "$STAGE_DIR/*" 2>/dev/null | head -n1)"
    if [ -n "$hit" ]; then
      echo "$hit"
      return 0
    fi
  done
  return 1
}

if ! SO_FILE="$(find_lib)"; then
  echo "Error: Could not find $LIB_NAME" >&2
  echo "Searched: $OUT_DIR and $ROOT_DIR/build/android-arm64" >&2
  find "$ROOT_DIR/build" -maxdepth 6 -name "libvulkan*.so" 2>/dev/null >&2 || true
  exit 1
fi
echo ">>> Using $SO_FILE"

# Sanity check: must be an aarch64 ELF shared object
if command -v file >/dev/null 2>&1; then
  file "$SO_FILE" | grep -qi "aarch64" || {
    echo "Error: $SO_FILE is not an aarch64 binary" >&2
    file "$SO_FILE" >&2
    exit 1
  }
fi

rm -rf "$STAGE_DIR" "$DIST_DIR"
mkdir -p "$STAGE_DIR" "$DIST_DIR"

cp "$SO_FILE" "$STAGE_DIR/$LIB_NAME"

cat > "$STAGE_DIR/meta.json" <<EOF
{
  "schemaVersion": 1,
  "name": "${DRIVER_NAME}",
  "driverVersion": "${DRIVER_VERSION}",
  "mesaCommit": "${MESA_COMMIT}",
  "libraryName": "${LIB_NAME}"
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
  python3 - "$STAGE_DIR" "$ZIP_PATH" <<'PY'
import os, sys, zipfile
src_dir, out_zip = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(out_zip, "w", compression=zipfile.ZIP_DEFLATED) as zf:
    for root, _, files in os.walk(src_dir):
        for f in files:
            full = os.path.join(root, f)
            zf.write(full, os.path.relpath(full, src_dir))
PY
fi

(
  cd "$DIST_DIR"
  sha256sum "$ZIP_NAME" > SHA256SUMS.txt
)

echo ">>> Packaged $ZIP_PATH"
