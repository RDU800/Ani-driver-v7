#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="${SRC_DIR:-$ROOT_DIR/build/mesa}"
PATCH_DIR="${PATCH_DIR:-$ROOT_DIR/patches}"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build/android-arm64}"
OUT_DIR="${OUT_DIR:-$ROOT_DIR/out/android-arm64}"
CROSS_FILE="${CROSS_FILE:-$ROOT_DIR/cross-android-arm64.txt}"

NDK_ROOT="${NDK_ROOT:-${ANDROID_NDK_ROOT:-/opt/android-ndk-r28c}}"
API_LEVEL="${API_LEVEL:-29}"

if [[ ! -d "$SRC_DIR" ]]; then
  echo "Error: Mesa source directory not found at $SRC_DIR" >&2
  exit 1
fi

# 1. Apply patches if present
if [[ -d "$PATCH_DIR" ]] && compgen -G "$PATCH_DIR/*.patch" > /dev/null; then
  echo "Applying patches from $PATCH_DIR..."
  git -C "$SRC_DIR" am --abort 2>/dev/null || true
  for p in "$PATCH_DIR"/*.patch; do
    echo "  -> $(basename "$p")"
    git -C "$SRC_DIR" am "$p"
  done
else
  echo "No patches directory or *.patch files found at $PATCH_DIR; skipping patch step."
fi

# 2. Generate Meson cross-file if not already provided
if [[ ! -f "$CROSS_FILE" ]]; then
  TOOLCHAIN_BIN="$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin"
  TARGET_TRIPLE="aarch64-linux-android${API_LEVEL}"

  cat > "$CROSS_FILE" <<EOF
[binaries]
c = '$TOOLCHAIN_BIN/${TARGET_TRIPLE}-clang'
cpp = '$TOOLCHAIN_BIN/${TARGET_TRIPLE}-clang++'
ar = '$TOOLCHAIN_BIN/llvm-ar'
strip = '$TOOLCHAIN_BIN/llvm-strip'
pkgconfig = 'pkg-config'

[properties]
needs_exe_wrapper = true

[host_machine]
system = 'android'
cpu_family = 'aarch64'
cpu = 'armv8-a'
endian = 'little'
EOF
fi

# 3. Configure with Meson
rm -rf "$BUILD_DIR"
meson setup "$BUILD_DIR" "$SRC_DIR" \
  --cross-file="$CROSS_FILE" \
  --prefix=/system \
  -Dbuildtype=release \
  -Dplatforms=android \
  -Dplatform-sdk-version="$API_LEVEL" \
  -Dandroid-stub=true \
  -Dvulkan-drivers=panfrost \
  -Dgallium-drivers= \
  -Dllvm=disabled \
  -Dglx=disabled \
  -Degl=disabled \
  -Dgbm=disabled \
  -Dvulkan-icd-dir=lib/vulkan/icd.d

# 4. Build and install into staging output directory
ninja -C "$BUILD_DIR" -j"$(nproc)"
DESTDIR="$OUT_DIR" ninja -C "$BUILD_DIR" install

echo "Build complete. Staged output at: $OUT_DIR"
