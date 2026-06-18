#!/bin/bash
#
# Build a MIPS big-endian bare-metal cross-compiler (mips-elf)
# for cross-compiling SGI PROM code on macOS.
#
# Usage: ./build-toolchain.sh [--clean]
#
# Installs to $PREFIX (default: $HOME/cross/mips-elf)
# Downloads binutils and GCC source to $BUILDDIR (default: /tmp/mips-toolchain-build)
#
set -euo pipefail

PREFIX="${MIPS_ELF_PREFIX:-$HOME/cross/mips-elf}"
BUILDDIR="${MIPS_ELF_BUILDDIR:-/tmp/mips-toolchain-build}"

BINUTILS_VER="2.43"
GCC_VER="14.2.0"

BINUTILS_URL="https://ftp.gnu.org/gnu/binutils/binutils-${BINUTILS_VER}.tar.xz"
GCC_URL="https://ftp.gnu.org/gnu/gcc/gcc-${GCC_VER}/gcc-${GCC_VER}.tar.xz"

NJOBS="$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
die()   { error "$@"; exit 1; }

# Handle --clean flag
if [[ "${1:-}" == "--clean" ]]; then
    info "Cleaning build directory: $BUILDDIR"
    rm -rf "$BUILDDIR"
    info "Cleaning install directory: $PREFIX"
    rm -rf "$PREFIX"
    info "Clean complete."
    exit 0
fi

info "MIPS bare-metal cross-compiler build"
info "  PREFIX:   $PREFIX"
info "  BUILDDIR: $BUILDDIR"
info "  JOBS:     $NJOBS"
info "  binutils: $BINUTILS_VER"
info "  GCC:      $GCC_VER"
echo

# Check if already installed
if [[ -x "$PREFIX/bin/mips-elf-gcc" ]]; then
    info "mips-elf-gcc already exists at $PREFIX/bin/mips-elf-gcc"
    "$PREFIX/bin/mips-elf-gcc" --version | head -1
    info "To rebuild, run: $0 --clean && $0"
    exit 0
fi

mkdir -p "$BUILDDIR" "$PREFIX"

# ── Step 1: Download sources ────────────────────────────────────────

download_if_missing() {
    local url="$1" dest="$2"
    if [[ -f "$dest" ]]; then
        info "Already downloaded: $(basename "$dest")"
    else
        info "Downloading: $(basename "$dest")"
        curl -L -o "$dest" "$url"
    fi
}

download_if_missing "$BINUTILS_URL" "$BUILDDIR/binutils-${BINUTILS_VER}.tar.xz"
download_if_missing "$GCC_URL"      "$BUILDDIR/gcc-${GCC_VER}.tar.xz"

# ── Step 2: Extract sources ─────────────────────────────────────────

extract_if_missing() {
    local archive="$1" dir="$2"
    if [[ -d "$dir" ]]; then
        info "Already extracted: $(basename "$dir")"
    else
        info "Extracting: $(basename "$archive")"
        tar xf "$archive" -C "$BUILDDIR"
    fi
}

extract_if_missing "$BUILDDIR/binutils-${BINUTILS_VER}.tar.xz" "$BUILDDIR/binutils-${BINUTILS_VER}"
extract_if_missing "$BUILDDIR/gcc-${GCC_VER}.tar.xz"           "$BUILDDIR/gcc-${GCC_VER}"

# ── Step 3: Build binutils ──────────────────────────────────────────

BINUTILS_BUILD="$BUILDDIR/build-binutils"

if [[ -x "$PREFIX/bin/mips-elf-as" ]]; then
    info "binutils already installed, skipping"
else
    info "Building binutils ${BINUTILS_VER}..."
    rm -rf "$BINUTILS_BUILD"
    mkdir -p "$BINUTILS_BUILD"
    cd "$BINUTILS_BUILD"

    MAKEINFO=true "../binutils-${BINUTILS_VER}/configure" \
        --target=mips-elf \
        --prefix="$PREFIX" \
        --disable-nls \
        --disable-werror \
        --with-system-zlib \
        2>&1 | tail -3

    make -j"$NJOBS" MAKEINFO=true
    make install MAKEINFO=true

    info "binutils installed."
    "$PREFIX/bin/mips-elf-as" --version | head -1
fi

# ── Step 4: Build GCC (C only, freestanding) ────────────────────────

export PATH="$PREFIX/bin:$PATH"

GCC_BUILD="$BUILDDIR/build-gcc"

if [[ -x "$PREFIX/bin/mips-elf-gcc" ]]; then
    info "GCC already installed, skipping"
else
    info "Building GCC ${GCC_VER} (C only, freestanding)..."
    rm -rf "$GCC_BUILD"
    mkdir -p "$GCC_BUILD"
    cd "$GCC_BUILD"

    # Detect Homebrew prefix for GMP/MPFR/MPC (needed by GCC)
    BREW_PREFIX="$(brew --prefix 2>/dev/null || echo /opt/homebrew)"
    GMP_DIR="$BREW_PREFIX"
    MPFR_DIR="$BREW_PREFIX"
    MPC_DIR="$BREW_PREFIX"

    # Try to find them in Cellar if not linked
    [[ -f "$GMP_DIR/include/gmp.h" ]] || GMP_DIR="$(brew --prefix gmp 2>/dev/null || echo "$BREW_PREFIX")"
    [[ -f "$MPFR_DIR/include/mpfr.h" ]] || MPFR_DIR="$(brew --prefix mpfr 2>/dev/null || echo "$BREW_PREFIX")"
    [[ -f "$MPC_DIR/include/mpc.h" ]] || MPC_DIR="$(brew --prefix libmpc 2>/dev/null || echo "$BREW_PREFIX")"

    info "GMP:  $GMP_DIR"
    info "MPFR: $MPFR_DIR"
    info "MPC:  $MPC_DIR"

    MAKEINFO=true "../gcc-${GCC_VER}/configure" \
        --target=mips-elf \
        --prefix="$PREFIX" \
        --enable-languages=c \
        --without-headers \
        --with-newlib \
        --disable-shared \
        --disable-threads \
        --disable-libssp \
        --disable-libgomp \
        --disable-libquadmath \
        --disable-libatomic \
        --disable-nls \
        --disable-multilib \
        --with-arch=mips3 \
        --with-abi=32 \
        --with-float=soft \
        --with-system-zlib \
        --with-gmp="$GMP_DIR" \
        --with-mpfr="$MPFR_DIR" \
        --with-mpc="$MPC_DIR" \
        2>&1 | tail -3

    make -j"$NJOBS" MAKEINFO=true all-gcc all-target-libgcc
    make install-gcc install-target-libgcc MAKEINFO=true

    info "GCC installed."
    "$PREFIX/bin/mips-elf-gcc" --version | head -1
fi

# ── Step 5: Verify ──────────────────────────────────────────────────

echo
info "Verification:"
"$PREFIX/bin/mips-elf-gcc" --version | head -1
"$PREFIX/bin/mips-elf-as"  --version | head -1
"$PREFIX/bin/mips-elf-ld"  --version | head -1

info "Multi-lib support:"
"$PREFIX/bin/mips-elf-gcc" -print-multi-lib

# Quick compile test
TMPF=$(mktemp /tmp/mips-test-XXXXXX.c)
cat > "$TMPF" <<'TESTEOF'
volatile unsigned int *uart = (volatile unsigned int *)0x1fb80070;
void _start(void) {
    *uart = 'H';
    *uart = 'i';
    while(1);
}
TESTEOF

if "$PREFIX/bin/mips-elf-gcc" -march=mips3 -mabi=32 -EB -ffreestanding -nostdlib -G 0 \
    -Wl,-Ttext=0xBFC00000 -o /tmp/mips-test.elf "$TMPF" 2>/dev/null; then
    "$PREFIX/bin/mips-elf-objdump" -d /tmp/mips-test.elf | head -20
    info "Compile test PASSED - produces MIPS III big-endian code"
    rm -f /tmp/mips-test.elf
else
    warn "Compile test failed (non-fatal, toolchain may still work)"
fi
rm -f "$TMPF"

echo
info "Toolchain ready at: $PREFIX/bin/"
info "Add to PATH:  export PATH=\"$PREFIX/bin:\$PATH\""
