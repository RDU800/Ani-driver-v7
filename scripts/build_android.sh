#!/usr/bin/env bash
set -euo pipefail

MESA_DIR="${1:-build/mesa}"
OUT_DIR="${2:-build/out}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# shellcheck disable=SC1090
source "$ROOT_DIR/sources.lock"

NDK_ROOT="${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-}}"
if [ -z "$NDK_ROOT" ] || [ ! -d "$NDK_ROOT" ]; then
  echo "Error: ANDROID_NDK_HOME or ANDROID_NDK_ROOT must point to a valid Android NDK directory." >&2
  exit 1
fi

HOST_TAG="linux-x86_64"
TOOLCHAIN="$NDK_ROOT/toolchains/llvm/prebuilt/$HOST_TAG"
CROSS_FILE="$OUT_DIR/android-aarch64.txt"

mkdir -p "$OUT_DIR"
sed -e "s|@NDK_TOOLCHAIN@|$TOOLCHAIN|g" \
    -e "s|@API@|$ANDROID_API|g" \
    "$ROOT_DIR/cross/android-aarch64.txt.in" > "$CROSS_FILE"

export CC="$TOOLCHAIN/bin/aarch64-linux-android${ANDROID_API}-clang"
export CXX="$TOOLCHAIN/bin/aarch64-linux-android${ANDROID_API}-clang++"
export AR="$TOOLCHAIN/bin/llvm-ar"
export STRIP="$TOOLCHAIN/bin/llvm-strip"
export PATH="$TOOLCHAIN/bin:$PATH"

meson setup "$OUT_DIR/meson-build" "$MESA_DIR" \
  --cross-file "$CROSS_FILE" \
  --buildtype=release \
  -Dplatforms=android \
  -Dplatform-sdk-version="$ANDROID_API" \
  -Dandroid-stub=true \
  -Dvulkan-drivers=panfrost \
  -Dgallium-drivers= \
  -Dglx=disabled \
  -Degl=disabled \
  -Dgbm=disabled \
  -Dvulkan-icd-dir=lib/vulkan/icd.d

ninja -C "$OUT_DIR/meson-build"

SO_PATH=$(find "$OUT_DIR/meson-build" -name "libvulkan_panfrost.so" | head -n 1)
if [ -z "$SO_PATH" ] || [ ! -f "$SO_PATH" ]; then
  echo "Error: libvulkan_panfrost.so was not produced." >&2
  exit 1
fi

cp "$SO_PATH" "$OUT_DIR/libvulkan_panfrost.so"
"$STRIP" --strip-unneeded "$OUT_DIR/libvulkan_panfrost.so"
echo ">>> Built driver: $OUT_DIR/libvulkan_panfrost.so"
