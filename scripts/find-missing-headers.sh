#!/bin/bash
#
# Find and copy all missing headers needed for C compilation.
# Iteratively tries to compile files and copies missing headers from the IRIX source tree.
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
IRIX_ROOT="${1:-$(cd "$PROJECT_DIR/../software_library/irix-657m-source" && pwd)}"

export PATH="$HOME/cross/mips-elf/bin:$PATH"
cd "$PROJECT_DIR"

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Files to test
C_FILES=(
    src/libsc/lib/ctype.c
    src/libsc/lib/atob.c
    src/libsc/lib/btoa.c
    src/libsc/lib/strnstuff.c
    src/libsc/lib/strstuff.c
    src/libsc/lib/strcasecmp.c
    src/libsc/lib/malloc.c
    src/libsc/lib/errputs.c
    src/libsc/lib/getenv.c
    src/libsc/lib/setenv.c
    src/libsc/lib/parser.c
    src/libsc/lib/menu.c
    src/libsc/lib/stdio.c
    src/libsc/lib/cmn_err.c
    src/libsc/lib/perror.c
    src/libsc/lib/stringlist.c
    src/libsc/lib/mem.c
    src/fw/stubs.c
    src/fw/main.c
    src/fw/finit.c
    src/lib/IP32k.c
    src/lib/st16c1451.c
    src/libsk/ml/env.c
    src/libsk/ml/delay.c
    src/libsk/io/mace_16c550.c
)

# Search paths for finding headers in IRIX source
SEARCH_PATHS=(
    "$IRIX_ROOT/stand/arcs/include"
    "$IRIX_ROOT/stand/arcs/IP32prom/include"
    "$IRIX_ROOT/irix/kern/sys"
    "$IRIX_ROOT/irix/kern"
    "$IRIX_ROOT/irix/include"
    "$IRIX_ROOT/eoe/include"
)

# Map of include path -> destination directory
resolve_header_dest() {
    local hdr="$1"
    case "$hdr" in
        sys/*)     echo "include/$hdr" ;;
        arcs/*)    echo "include/$hdr" ;;
        *)         echo "include/$hdr" ;;
    esac
}

# Find a header in IRIX source tree
find_header() {
    local hdr="$1"
    for sp in "${SEARCH_PATHS[@]}"; do
        if [[ -f "$sp/$hdr" ]]; then
            echo "$sp/$hdr"
            return 0
        fi
    done
    return 1
}

COPIED=0
MISSING_UNFOUND=()

# Run multiple passes to catch transitive dependencies
for pass in 1 2 3 4 5; do
    echo -e "\n${GREEN}=== Pass $pass ===${NC}"
    found_new=false

    for f in "${C_FILES[@]}"; do
        [[ -f "$f" ]] || continue

        # Try to compile and capture missing headers
        output=$(make try-compile FILE="$f" 2>&1)
        if echo "$output" | grep -q "^OK:"; then
            continue
        fi

        # Extract missing header names
        missing=$(echo "$output" | grep "fatal error:.*: No such file or directory" | \
                  sed 's/.*fatal error: //; s/: No such file.*//' | sort -u)

        for hdr in $missing; do
            dest=$(resolve_header_dest "$hdr")
            if [[ -f "$PROJECT_DIR/$dest" ]]; then
                continue  # Already exists
            fi

            src=$(find_header "$hdr")
            if [[ -n "$src" ]]; then
                mkdir -p "$(dirname "$PROJECT_DIR/$dest")"
                cp "$src" "$PROJECT_DIR/$dest"
                echo -e "  ${GREEN}COPIED${NC}: $hdr -> $dest"
                COPIED=$((COPIED + 1))
                found_new=true
            else
                if ! printf '%s\n' "${MISSING_UNFOUND[@]}" 2>/dev/null | grep -qx "$hdr"; then
                    MISSING_UNFOUND+=("$hdr")
                    echo -e "  ${YELLOW}NOT FOUND${NC}: $hdr"
                fi
            fi
        done
    done

    if [[ "$found_new" == false ]]; then
        echo "  No new headers found, stopping."
        break
    fi
done

echo
echo "Copied $COPIED headers."
if [[ ${#MISSING_UNFOUND[@]} -gt 0 ]]; then
    echo "Could not find (need stubs):"
    printf '  %s\n' "${MISSING_UNFOUND[@]}"
fi

# Final test
echo
echo -e "${GREEN}=== Final compilation results ===${NC}"
PASS=0; FAIL=0
for f in "${C_FILES[@]}"; do
    [[ -f "$f" ]] || continue
    result=$(make try-compile FILE="$f" 2>&1)
    if echo "$result" | grep -q "^OK:"; then
        echo -e "  ${GREEN}PASS${NC}: $f"
        PASS=$((PASS + 1))
    else
        echo -e "  ${YELLOW}FAIL${NC}: $f"
        echo "$result" | grep -i "fatal error\|error:" | sed 's/^/    /' | uniq | head -3
        FAIL=$((FAIL + 1))
    fi
done
echo
echo "Total: $PASS pass, $FAIL fail"
