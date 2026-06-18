#!/bin/bash
#
# Copy IP32prom source files from the IRIX 6.5.7m source tree
# into the prom-building/ project structure.
#
# Usage: ./setup-sources.sh [IRIX_SOURCE_ROOT]
#
set -uo pipefail
# Note: not using -e so a missing file warning doesn't abort the whole script

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
IRIX_ROOT="${1:-$(cd "$PROJECT_DIR/../software_library/irix-657m-source" && pwd)}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
die()   { error "$@"; exit 1; }

# Verify IRIX source root exists
[[ -d "$IRIX_ROOT/stand/arcs/IP32prom" ]] || die "IRIX source root not found at: $IRIX_ROOT"

info "IRIX source root: $IRIX_ROOT"
info "Project directory: $PROJECT_DIR"

# Shorthand paths
PROM="$IRIX_ROOT/stand/arcs/IP32prom"
LIBSK="$IRIX_ROOT/stand/arcs/lib/libsk"
LIBSC="$IRIX_ROOT/stand/arcs/lib/libsc"
ARCS_INC="$IRIX_ROOT/stand/arcs/include"
KERN_SYS="$IRIX_ROOT/irix/kern/sys"
IRIX_INC="$IRIX_ROOT/irix/include"

# Helper: copy file, creating destination directory
copy_file() {
    local src="$1" dst="$2"
    if [[ ! -f "$src" ]]; then
        warn "Source not found: $src"
        return 1
    fi
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
}

# Helper: copy all files from source dir to dest dir
copy_dir_files() {
    local src_dir="$1" dst_dir="$2" pattern="${3:-*}"
    if [[ ! -d "$src_dir" ]]; then
        warn "Source directory not found: $src_dir"
        return 1
    fi
    mkdir -p "$dst_dir"
    local count=0
    for f in "$src_dir"/$pattern; do
        [[ -f "$f" ]] || continue
        cp "$f" "$dst_dir/"
        count=$((count + 1))
    done
    echo "  $count files"
}

echo

# ── Create directory structure ───────────────────────────────────────

info "Creating directory structure..."
mkdir -p "$PROJECT_DIR"/{src/{boot,fw,lib/caches,libsk/{ml,io,graphics},libsc/lib},include/{sys,arcs},compat/arcs,link,tools/flashbuild}

# ── IP32prom firmware core (→ src/fw/) ───────────────────────────────

info "Copying IP32prom firmware (src/fw/)..."
for f in csu.s finit.c main.c stubs.c video.c IP32conf.cf fsconf.cf; do
    copy_file "$PROM/fw/$f" "$PROJECT_DIR/src/fw/$f"
done
# Video chip headers used by video.c
for f in mvp7111.h mvp7185.h; do
    copy_file "$PROM/fw/$f" "$PROJECT_DIR/src/fw/$f"
done

# ── IP32prom POST (→ src/boot/) ──────────────────────────────────────

info "Copying IP32prom POST (src/boot/)..."
for f in post1.s post1csu.s post1asmsupt.s post1memtst.s post1mem.c \
         post1diags.c ser_post.c pciio.c DBCuartio.c DBCuartsim.c \
         post2_graphics.c post23.s post3diags.c \
         sio.h st16c1451.c TL16550.h; do
    copy_file "$PROM/post/$f" "$PROJECT_DIR/src/boot/$f"
done

# ── IP32prom platform library (→ src/lib/) ───────────────────────────

info "Copying IP32prom library (src/lib/)..."
for f in IP32k.c IP32asm.s usecdelay.s tile.c ds2502.c \
         mte_copy.c mte_stubs.c mte_asm.s st16c1451.c \
         DBCuartio.c DBCuartsim.c; do
    copy_file "$PROM/lib/$f" "$PROJECT_DIR/src/lib/$f"
done

# Cache support
info "Copying cache support (src/lib/caches/)..."
for f in cache_mi.c r4400_cache.s r5000_cache.s r10000_cache.s r4600_cache.s; do
    copy_file "$PROM/lib/caches/$f" "$PROJECT_DIR/src/lib/caches/$f"
done

# ── libsk subset (→ src/libsk/) ──────────────────────────────────────

info "Copying libsk/ml/ (machine-dependent)..."
for f in IP32.c IP32asm.s IP32_cacheops.s IP32tci.s \
         startup.c env.c flash.c flashwrite.c \
         ds1685.c ds2502.c r4k.c delay.c badaddr.c \
         csu.s faultasm.s genasm.s; do
    copy_file "$LIBSK/ml/$f" "$PROJECT_DIR/src/libsk/ml/$f"
done

info "Copying libsk/io/ (I/O drivers)..."
for f in mace_16c550.c pci_intf.c; do
    copy_file "$LIBSK/io/$f" "$PROJECT_DIR/src/libsk/io/$f"
done

info "Copying libsk/graphics/CRIME/ (graphics stubs)..."
if [[ -d "$LIBSK/graphics/CRIME" ]]; then
    copy_dir_files "$LIBSK/graphics/CRIME" "$PROJECT_DIR/src/libsk/graphics" "*.c"
fi

# ── libsc subset (→ src/libsc/) ──────────────────────────────────────

info "Copying libsc/lib/ (standalone C library)..."
for f in malloc.c stdio.c setjmp.s atob.c btoa.c ctype.c \
         strnstuff.c strstuff.c getenv.c setenv.c parser.c menu.c \
         cmn_err.c errputs.c perror.c strcasecmp.c \
         stringlist.c libasm.s mem.c auto.c \
         invfind.c restart.c screen.c pause.c \
         expand.c panel.c path.c getpath.c bootname.c \
         large.c range_check.c random.c; do
    copy_file "$LIBSC/lib/$f" "$PROJECT_DIR/src/libsc/lib/$f"
done

# ── Kernel headers (→ include/sys/) ──────────────────────────────────

info "Copying kernel headers (include/sys/)..."
for f in crime.h mace.h IP32.h IP32flash.h cpu.h sbd.h ds17287.h \
         regdef.h asm.h types.h mips_addrspace.h; do
    copy_file "$KERN_SYS/$f" "$PROJECT_DIR/include/sys/$f"
done

# sgidefs.h from irix/include/
copy_file "$IRIX_INC/sgidefs.h" "$PROJECT_DIR/include/sgidefs.h"

# genpda.h from stand/arcs/include/
copy_file "$ARCS_INC/genpda.h" "$PROJECT_DIR/include/genpda.h"

# ── ARCS headers (→ include/arcs/) ───────────────────────────────────

info "Copying ARCS headers (include/arcs/)..."
for f in restart.h cfgdata.h cfgtree.h eiob.h errno.h \
         folder.h fs.h prom_callout.h dload.h dlsafe.h; do
    copy_file "$ARCS_INC/arcs/$f" "$PROJECT_DIR/include/arcs/$f"
done

# Stand/arcs top-level includes
info "Copying stand/arcs includes..."
for f in libsc.h libsk.h fault.h flash.h parser.h setjmp.h menu.h \
         guicore.h gfxgui.h trace.h stringlist.h IP32_status.h; do
    copy_file "$ARCS_INC/$f" "$PROJECT_DIR/include/$f"
done

# Also look for headers in ARCS include/sys/ (distinct from kernel sys/)
if [[ -d "$ARCS_INC/sys" ]]; then
    info "Copying stand/arcs/include/sys/ headers..."
    copy_dir_files "$ARCS_INC/sys" "$PROJECT_DIR/include/arcs_sys"
fi

# ── IP32prom-specific include/ ───────────────────────────────────────

info "Copying IP32prom/include/ headers..."
for f in caches.h crm_fb.h crm_i2c.h crm_stand.h crmDefs.h cursor.h \
         DBCsim.h DBCuartsim.h flash.h mace_ec.h pci.h post1supt.h \
         sio.h st16c1451.h tiles.h trace.h TL16550.h; do
    copy_file "$PROM/include/$f" "$PROJECT_DIR/include/ip32/$f"
done

# IP32prom/include/sys/ (CRIME-specific headers)
if [[ -d "$PROM/include/sys" ]]; then
    info "Copying IP32prom/include/sys/ (CRIME-specific)..."
    copy_dir_files "$PROM/include/sys" "$PROJECT_DIR/include/ip32/sys"
fi

# ── flashbuild host tool (→ tools/flashbuild/) ──────────────────────

info "Copying flashbuild tool (tools/flashbuild/)..."
for f in main.c buildFlash.c elfFiles.c writeHex.c fb.h Makefile; do
    copy_file "$PROM/tools/flashbuild/$f" "$PROJECT_DIR/tools/flashbuild/$f"
done

# ── Summary ──────────────────────────────────────────────────────────

echo
info "Source copy complete!"
echo
info "Directory structure:"
find "$PROJECT_DIR/src" "$PROJECT_DIR/include" "$PROJECT_DIR/tools" \
    -type f 2>/dev/null | wc -l | xargs -I{} echo "  {} files copied"
echo
info "Next steps:"
info "  1. Run build-toolchain.sh to build the cross-compiler"
info "  2. Run 'make' to build the PROM"
