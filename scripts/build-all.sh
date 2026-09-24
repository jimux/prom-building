#!/bin/bash
#
# build-all.sh -- Complete paravirtual PROM build pipeline
#
# This script runs all phases in order:
#   1. Build cross-compiler (if not present)
#   2. Copy IRIX source files (if not present)
#   3. Build flashbuild host tool
#   4. Attempt to compile assembly files
#   5. Attempt to compile C files
#   6. Report results
#
# Stops at the first phase that fails and reports what needs fixing.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
section() { echo -e "\n${BLUE}════════════════════════════════════════${NC}"; echo -e "${BLUE}  $*${NC}"; echo -e "${BLUE}════════════════════════════════════════${NC}\n"; }

PASS=0
FAIL=0
SKIP=0

# ── Phase 0: Cross-compiler ─────────────────────────────────────────

section "Phase 0: Cross-Compiler Toolchain"

PREFIX="${MIPS_ELF_PREFIX:-$HOME/cross/mips-elf}"
if [[ -x "$PREFIX/bin/mips-elf-gcc" ]]; then
    info "Cross-compiler already installed."
    "$PREFIX/bin/mips-elf-gcc" --version | head -1
    PASS=$((PASS + 1))
else
    info "Building cross-compiler..."
    if bash scripts/build-toolchain.sh; then
        PASS=$((PASS + 1))
    else
        error "Cross-compiler build failed!"
        error "Check the output above and try running scripts/build-toolchain.sh manually."
        exit 1
    fi
fi

export PATH="$PREFIX/bin:$PATH"

# ── Phase 1: Source setup ────────────────────────────────────────────

section "Phase 1: Source File Setup"

if [[ -f "src/fw/csu.s" && -f "src/fw/main.c" ]]; then
    info "Source files already copied."
    PASS=$((PASS + 1))
else
    info "Copying source files from IRIX tree..."
    if bash scripts/setup-sources.sh; then
        PASS=$((PASS + 1))
    else
        error "Source setup failed!"
        exit 1
    fi
fi

# ── Phase 2: flashbuild host tool ────────────────────────────────────

section "Phase 2: flashbuild Host Tool"

if [[ -f "tools/flashbuild/main.c" ]]; then
    if make flashbuild 2>&1; then
        info "flashbuild built successfully."
        PASS=$((PASS + 1))
    else
        warn "flashbuild failed to build (non-fatal, may need source fixes)."
        FAIL=$((FAIL + 1))
    fi
else
    warn "flashbuild sources not found, skipping."
    SKIP=$((SKIP + 1))
fi

# ── Phase 3: Assembly compilation ────────────────────────────────────

section "Phase 3: Assembly Compilation"

ASM_PASS=0
ASM_FAIL=0
ASM_FILES=(
    src/fw/csu.s
    src/lib/IP32asm.s
    src/lib/usecdelay.s
    src/lib/mte_asm.s
    src/libsc/lib/setjmp.s
    src/libsc/lib/libasm.s
)

for f in "${ASM_FILES[@]}"; do
    if [[ ! -f "$f" ]]; then
        warn "  SKIP: $f (not found)"
        continue
    fi
    if make try-asm FILE="$f" 2>&1 | tail -1 | grep -q "^OK:"; then
        info "  PASS: $f"
        ASM_PASS=$((ASM_PASS + 1))
    else
        error "  FAIL: $f"
        make try-asm FILE="$f" 2>&1 | grep -i "error" | head -5
        ASM_FAIL=$((ASM_FAIL + 1))
    fi
done

echo
info "Assembly: $ASM_PASS passed, $ASM_FAIL failed out of ${#ASM_FILES[@]}"
if [[ $ASM_FAIL -eq 0 ]]; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
fi

# ── Phase 4: C compilation ──────────────────────────────────────────

section "Phase 4: C File Compilation"

C_PASS=0
C_FAIL=0
C_ERRORS=()

# Test each tier separately
for tier_name in "Tier1:libsc" "Tier2:platform" "Tier3:libsk" "Tier4:firmware"; do
    tier_label="${tier_name%%:*}"
    tier_desc="${tier_name##*:}"

    case "$tier_label" in
        Tier1) tier_files=(src/libsc/lib/ctype.c src/libsc/lib/atob.c src/libsc/lib/btoa.c \
                           src/libsc/lib/strnstuff.c src/libsc/lib/strstuff.c src/libsc/lib/malloc.c \
                           src/libsc/lib/errputs.c src/libsc/lib/getenv.c src/libsc/lib/setenv.c \
                           src/libsc/lib/parser.c src/libsc/lib/menu.c src/libsc/lib/stdio.c) ;;
        Tier2) tier_files=(src/lib/IP32k.c src/lib/mte_copy.c src/lib/mte_stubs.c \
                           src/lib/tile.c src/lib/st16c1451.c) ;;
        Tier3) tier_files=(src/libsk/ml/env.c src/libsk/ml/delay.c src/libsk/ml/badaddr.c \
                           src/libsk/io/mace_16c550.c) ;;
        Tier4) tier_files=(src/fw/stubs.c src/fw/main.c src/fw/finit.c) ;;
    esac

    echo -e "\n  ${BLUE}--- $tier_label ($tier_desc) ---${NC}"
    for f in "${tier_files[@]}"; do
        if [[ ! -f "$f" ]]; then
            warn "    SKIP: $f (not found)"
            continue
        fi
        output=$(make try-compile FILE="$f" 2>&1)
        if echo "$output" | tail -1 | grep -q "^OK:"; then
            info "    PASS: $f"
            C_PASS=$((C_PASS + 1))
        else
            error "    FAIL: $f"
            echo "$output" | grep -i "error" | head -3 | sed 's/^/      /'
            C_FAIL=$((C_FAIL + 1))
            C_ERRORS+=("$f")
        fi
    done
done

echo
info "C compilation: $C_PASS passed, $C_FAIL failed"
if [[ ${#C_ERRORS[@]} -gt 0 ]]; then
    warn "Failed files:"
    for f in "${C_ERRORS[@]}"; do
        echo "  - $f"
    done
    FAIL=$((FAIL + 1))
else
    PASS=$((PASS + 1))
fi

# ── Summary ──────────────────────────────────────────────────────────

section "Build Summary"

echo -e "  Phases passed:  ${GREEN}$PASS${NC}"
echo -e "  Phases failed:  ${RED}$FAIL${NC}"
echo -e "  Phases skipped: ${YELLOW}$SKIP${NC}"
echo
echo -e "  Assembly: ${GREEN}$ASM_PASS${NC} pass / ${RED}$ASM_FAIL${NC} fail"
echo -e "  C files:  ${GREEN}$C_PASS${NC} pass / ${RED}$C_FAIL${NC} fail"

if [[ $FAIL -eq 0 ]]; then
    echo
    info "All phases passed! Try 'make all' to link the final binary."
else
    echo
    warn "Some phases failed. Fix the errors above and re-run."
fi
