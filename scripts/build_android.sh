#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="${1:-${SRC_DIR:-$ROOT_DIR/build/mesa}}"
OUT_DIR="${2:-${OUT_DIR:-$ROOT_DIR/build/out}}"

PATCH_DIR="${PATCH_DIR:-$ROOT_DIR/patches}"
LIBDRM_SRC_DIR="${LIBDRM_SRC_DIR:-$ROOT_DIR/build/libdrm}"
LIBDRM_BUILD_DIR="${LIBDRM_BUILD_DIR:-$ROOT_DIR/build/libdrm-android-arm64}"
LIBDRM_PREFIX="${LIBDRM_PREFIX:-$ROOT_DIR/build/deps-android-arm64}"

MESA_BUILD_DIR="${MESA_BUILD_DIR:-$ROOT_DIR/build/android-arm64}"
CROSS_FILE="${CROSS_FILE:-$ROOT_DIR/cross-android-arm64.txt}"

NDK_ROOT="${NDK_ROOT:-${ANDROID_NDK_ROOT:-${ANDROID_NDK_HOME:-/opt/ndk/android-ndk-r28c}}}"
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
pkg-config = 'pkg-config'

[properties]
needs_exe_wrapper = true

[host_machine]
system = 'android'
cpu_family = 'aarch64'
cpu = 'armv8-a'
endian = 'little'
EOF
fi

# 3. Build libdrm for Android aarch64
if [[ ! -d "$LIBDRM_SRC_DIR" ]]; then
  git clone --depth=1 https://gitlab.freedesktop.org/mesa/drm.git "$LIBDRM_SRC_DIR"
fi

rm -rf "$LIBDRM_BUILD_DIR" "$LIBDRM_PREFIX"
meson setup "$LIBDRM_BUILD_DIR" "$LIBDRM_SRC_DIR" \
  --cross-file="$CROSS_FILE" \
  --prefix="$LIBDRM_PREFIX" \
  -Dudev=false \
  -Dvalgrind=disabled \
  -Dfreedreno=disabled \
  -Detnaviv=disabled \
  -Dexynos=disabled \
  -Domap=disabled \
  -Dtegra=disabled \
  -Dvc4=disabled \
  -Dvmwgfx=disabled \
  -Dradeon=false \
  -Damdgpu=false \
  -Dnouveau=false \
  -Dintel=false

ninja -C "$LIBDRM_BUILD_DIR" -j"$(nproc)"
ninja -C "$LIBDRM_BUILD_DIR" install

export PKG_CONFIG_PATH="$LIBDRM_PREFIX/lib/pkgconfig${LIBDRM_PREFIX}/lib/aarch64-linux-gnu/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"

# 4. Configure and build Mesa PanVK
rm -rf "$MESA_BUILD_DIR"
meson setup "$MESA_BUILD_DIR" "$SRC_DIR" \
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

ninja -C "$MESA_BUILD_DIR" -j"$(nproc)"
DESTDIR="$OUT_DIR" ninja -C "$MESA_BUILD_DIR" install

echo "Build complete. Staged output at: $OUT_DIR"
