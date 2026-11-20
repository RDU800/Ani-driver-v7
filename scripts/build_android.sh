#!/usr/bin/env bash
set -euo pipefail

MESA_DIR="${1:-build/mesa}"
OUT_DIR="${2:-build/out}"
NDK_DIR="${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-/opt/ndk/android-ndk-r28c}}"
API_LEVEL="${ANDROID_PLATFORM_API:-29}"

TOOLCHAIN_BIN="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/bin"
CLANG="$TOOLCHAIN_BIN/aarch64-linux-android${API_LEVEL}-clang"
CLANGXX="$TOOLCHAIN_BIN/aarch64-linux-android${API_LEVEL}-clang++"
AR="$TOOLCHAIN_BIN/llvm-ar"
LD="$TOOLCHAIN_BIN/ld.lld"
STRIP="$TOOLCHAIN_BIN/llvm-strip"

if [ ! -x "$CLANG" ]; then
  echo "ERROR: Android NDK clang not found at: $CLANG" >&2
  exit 1
fi

mkdir -p "$OUT_DIR" "$MESA_DIR/subprojects"

CROSS_FILE="$OUT_DIR/android-aarch64.txt"
cat <<EOF > "$CROSS_FILE"
[binaries]
c = '$CLANG'
cpp = '$CLANGXX'
ar = '$AR'
ld = '$LD'
strip = '$STRIP'
pkg-config = '/usr/bin/false'

[host_machine]
system = 'android'
cpu_family = 'aarch64'
cpu = 'armv8.2-a'
endian = 'little'
EOF

# Provide libdrm for the Android aarch64 cross-build when not already present
if [ ! -e "$MESA_DIR/subprojects/libdrm" ] && [ ! -f "$MESA_DIR/subprojects/libdrm.wrap" ]; then
  cat <<'EOF' > "$MESA_DIR/subprojects/libdrm.wrap"
[wrap-git]
url = https://gitlab.freedesktop.org/mesa/drm.git
revision = main
depth = 1
EOF
fi

BUILD_DIR="$OUT_DIR/meson-build"
rm -rf "$BUILD_DIR"

meson setup "$BUILD_DIR" "$MESA_DIR" \
  --cross-file="$CROSS_FILE" \
  -Dbuildtype=release \
  -Dplatforms=android \
  -Dplatform-sdk-version="$API_LEVEL" \
  -Dandroid-stub=true \
  -Dvulkan-drivers=panfrost \
  -Dgallium-drivers= \
  -Dglx=disabled \
  -Degl=disabled \
  -Dgbm=disabled \
  -Dvulkan-icd-dir=lib/vulkan/icd.d

ninja -C "$BUILD_DIR"

SO_PATH="$(find "$BUILD_DIR" -name 'libvulkan_panfrost.so' -print -quit || true)"
if [ -z "$SO_PATH" ]; then
  echo "ERROR: libvulkan_panfrost.so was not produced in $BUILD_DIR" >&2
  exit 1
fi

cp -f "$SO_PATH" "$OUT_DIR/libvulkan_panfrost.so"
"$STRIP" --strip-unneeded "$OUT_DIR/libvulkan_panfrost.so" || true
echo ">>> Built PanVK driver: $OUT_DIR/libvulkan_panfrost.so"
