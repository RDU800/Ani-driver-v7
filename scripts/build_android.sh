#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="${1:-${SRC_DIR:-$ROOT_DIR/build/mesa}}"
OUT_DIR="${2:-${OUT_DIR:-$ROOT_DIR/build/out}}"

PATCH_DIR="${PATCH_DIR:-$ROOT_DIR/patches}"
LIBDRM_SRC_DIR="${LIBDRM_SRC_DIR:-$ROOT_DIR/build/libdrm}"
LIBDRM_BUILD_DIR="${LIBDRM_BUILD_DIR:-$ROOT_DIR/build/libdrm-android-arm64}"
LIBDRM_PREFIX="${LIBDRM_PREFIX:-$ROOT_DIR/build/deps-android-arm64}"

# Native (host) build that produces mesa_clc / precomp compiler for the cross build
HOST_BUILD_DIR="${HOST_BUILD_DIR:-$ROOT_DIR/build/mesa-host}"
HOST_PREFIX="${HOST_PREFIX:-$ROOT_DIR/build/host-tools}"

MESA_BUILD_DIR="${MESA_BUILD_DIR:-$ROOT_DIR/build/android-arm64}"
CROSS_FILE="${CROSS_FILE:-$ROOT_DIR/cross-android-arm64.txt}"
PKG_CROSS_FILE="$ROOT_DIR/build/cross-pkgconfig.txt"

NDK_ROOT="${NDK_ROOT:-${ANDROID_NDK_ROOT:-${ANDROID_NDK_HOME:-/opt/ndk/android-ndk-r28c}}}"
API_LEVEL="${API_LEVEL:-29}"

if [[ ! -d "$SRC_DIR" ]]; then
  echo "Error: Mesa source directory not found at $SRC_DIR" >&2
  exit 1
fi

mkdir -p "$ROOT_DIR/build"

# ---------------------------------------------------------------------------
# Helpers: only pass meson options that the checked-out source actually defines
# ---------------------------------------------------------------------------
find_opt_file() {
  local dir="$1"
  if [[ -f "$dir/meson.options" ]]; then echo "$dir/meson.options"
  else echo "$dir/meson_options.txt"; fi
}

has_opt() { # has_opt <options-file> <name>
  grep -qE "['\"]$2['\"]" "$1"
}

# Emit "-Dname=disabled|false" if the option exists, based on its declared type
disable_opt() { # disable_opt <options-file> <name>
  local file="$1" name="$2" type
  has_opt "$file" "$name" || return 0
  type="$(awk -v n="'${name}'" '$0 ~ n {f=1} f && /type[[:space:]]*:/ {print; exit}' "$file")"
  if [[ "$type" == *feature* ]]; then echo "-D${name}=disabled"; else echo "-D${name}=false"; fi
}


# ---------------------------------------------------------------------------
# 1. Apply flat patches only if not already applied by apply_patches.sh
# ---------------------------------------------------------------------------
if [[ "${SKIP_PATCH_IN_BUILD:-1}" != "1" ]] && [[ -d "$PATCH_DIR" ]] && compgen -G "$PATCH_DIR/*.patch" > /dev/null; then
  echo "Applying patches from $PATCH_DIR..."
  git -C "$SRC_DIR" am --abort 2>/dev/null || true
  for p in "$PATCH_DIR"/*.patch; do
    echo "  -> $(basename "$p")"
    git -C "$SRC_DIR" am --3way "$p"
  done
else
  echo "Skipping patch step in build_android.sh (handled by apply_patches.sh or no *.patch files)."
fi

# ---------------------------------------------------------------------------
# 2. Generate Meson cross-file if not already provided
# ---------------------------------------------------------------------------
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
rust = ['rustc', '--target', 'aarch64-linux-android']

[properties]
needs_exe_wrapper = true

[host_machine]
system = 'android'
cpu_family = 'aarch64'
cpu = 'armv8-a'
endian = 'little'
EOF
fi

# Meson ignores PKG_CONFIG_PATH in cross builds, so point pkg-config at the
# libdrm prefix through a second cross-file instead.
cat > "$PKG_CROSS_FILE" <<EOF
[properties]
pkg_config_libdir = ['$LIBDRM_PREFIX/lib/pkgconfig']
EOF

# ---------------------------------------------------------------------------
# 3. Build libdrm for Android aarch64
# ---------------------------------------------------------------------------
if [[ ! -d "$LIBDRM_SRC_DIR" ]]; then
  git clone --depth=1 https://gitlab.freedesktop.org/mesa/drm.git "$LIBDRM_SRC_DIR"
fi

DRM_OPT_FILE="$(find_opt_file "$LIBDRM_SRC_DIR")"
LIBDRM_OPTS=()
for o in udev valgrind tests cairo-tests man-pages \
         intel radeon amdgpu nouveau vmwgfx omap exynos \
         freedreno tegra vc4 etnaviv; do
  arg="$(disable_opt "$DRM_OPT_FILE" "$o")"
  [[ -n "$arg" ]] && LIBDRM_OPTS+=("$arg")
done
echo "libdrm options: ${LIBDRM_OPTS[*]}"

rm -rf "$LIBDRM_BUILD_DIR" "$LIBDRM_PREFIX"
meson setup "$LIBDRM_BUILD_DIR" "$LIBDRM_SRC_DIR" \
  --cross-file="$CROSS_FILE" \
  --prefix="$LIBDRM_PREFIX" \
  --libdir=lib \
  "${LIBDRM_OPTS[@]}"

ninja -C "$LIBDRM_BUILD_DIR" -j"$(nproc)"
ninja -C "$LIBDRM_BUILD_DIR" install

# ---------------------------------------------------------------------------
# 4. Native build of Mesa's host tools (mesa_clc, precomp compiler)
#    PanVK needs these at build time and they must run on the build machine.
# ---------------------------------------------------------------------------
MESA_OPT_FILE="$(find_opt_file "$SRC_DIR")"

HOST_OPTS=()
has_opt "$MESA_OPT_FILE" mesa-clc               && HOST_OPTS+=(-Dmesa-clc=enabled)
has_opt "$MESA_OPT_FILE" install-mesa-clc       && HOST_OPTS+=(-Dinstall-mesa-clc=true)
has_opt "$MESA_OPT_FILE" precomp-compiler       && HOST_OPTS+=(-Dprecomp-compiler=enabled)
has_opt "$MESA_OPT_FILE" install-precomp-compiler && HOST_OPTS+=(-Dinstall-precomp-compiler=true)

if [[ ${#HOST_OPTS[@]} -gt 0 ]]; then
  LLVM_VER="${LLVM_VER:-20}"
  LLVM_CONFIG_BIN="/usr/bin/llvm-config-${LLVM_VER}"
  CLANG_BIN="/usr/bin/clang-${LLVM_VER}"
  if [[ ! -x "$LLVM_CONFIG_BIN" ]]; then
    echo "Error: $LLVM_CONFIG_BIN not found. Install llvm-${LLVM_VER}-dev libclang-${LLVM_VER}-dev libclc-${LLVM_VER}-dev libllvmspirvlib-${LLVM_VER}-dev." >&2
    exit 1
  fi
  
  export LIBCLANG_PATH="${LIBCLANG_PATH:-$("$LLVM_CONFIG_BIN" --libdir)}"
  if [[ -x "$CLANG_BIN" ]]; then
    CLANG_RES_DIR="$("$CLANG_BIN" -print-resource-dir)"
    export BINDGEN_EXTRA_CLANG_ARGS="${BINDGEN_EXTRA_CLANG_ARGS:-} -resource-dir=${CLANG_RES_DIR}"
  fi

  NATIVE_FILE="$ROOT_DIR/build/native-llvm.txt"
  cat > "$NATIVE_FILE" <<EOF
[binaries]
llvm-config = '$LLVM_CONFIG_BIN'
EOF

  echo "Building native host tools with: ${HOST_OPTS[*]}"
  rm -rf "$HOST_BUILD_DIR" "$HOST_PREFIX"
  meson setup "$HOST_BUILD_DIR" "$SRC_DIR" \
    --native-file="$NATIVE_FILE" \
    --prefix="$HOST_PREFIX" \
    -Dbuildtype=release \
    -Dllvm=enabled \
    -Dplatforms= \
    -Dglx=disabled \
    -Degl=disabled \
    -Dgbm=disabled \
    -Dgles1=disabled \
    -Dgles2=disabled \
    -Dopengl=false \
    -Dgallium-drivers= \
    -Dvulkan-drivers="${NATIVE_VK_DRIVERS:-panfrost}" \
    "${HOST_OPTS[@]}"
  ninja -C "$HOST_BUILD_DIR" -j"$(nproc)"
  ninja -C "$HOST_BUILD_DIR" install
  export PATH="$HOST_PREFIX/bin:$PATH"
fi

CROSS_CLC_OPTS=()
has_opt "$MESA_OPT_FILE" mesa-clc         && CROSS_CLC_OPTS+=(-Dmesa-clc=system)
has_opt "$MESA_OPT_FILE" precomp-compiler && CROSS_CLC_OPTS+=(-Dprecomp-compiler=system)

# ---------------------------------------------------------------------------
# 5. Configure and build Mesa PanVK for Android
# ---------------------------------------------------------------------------
EXTRA_OPTS=()
has_opt "$MESA_OPT_FILE" android-libbacktrace && EXTRA_OPTS+=(-Dandroid-libbacktrace=disabled)
has_opt "$MESA_OPT_FILE" build-tests          && EXTRA_OPTS+=(-Dbuild-tests=false)

EXPAT_FALLBACK_OPT=()
if [[ -f "$SRC_DIR/subprojects/expat.wrap" ]]; then
  EXPAT_FALLBACK_OPT+=(--force-fallback-for=expat)
fi
NDK_SYSROOT="$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
NDK_CLANG="$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android${API_LEVEL}-clang"
NDK_RES_DIR="$("$NDK_CLANG" -print-resource-dir)"

# Override host flags from Step 4 so bindgen uses Android Bionic headers
export BINDGEN_EXTRA_CLANG_ARGS="--sysroot=${NDK_SYSROOT} -resource-dir=${NDK_RES_DIR}"
rm -rf "$MESA_BUILD_DIR"
meson setup "$MESA_BUILD_DIR" "$SRC_DIR" \
  --cross-file="$CROSS_FILE" \
  --cross-file="$PKG_CROSS_FILE" \
  "${EXPAT_FALLBACK_OPT[@]}" \
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
  -Dvulkan-icd-dir=lib/vulkan/icd.d \
  "${CROSS_CLC_OPTS[@]}" \
  "${EXTRA_OPTS[@]}"

ninja -C "$MESA_BUILD_DIR" -j"$(nproc)"
DESTDIR="$OUT_DIR" ninja -C "$MESA_BUILD_DIR" install

echo "Build complete. Staged output at: $OUT_DIR"
