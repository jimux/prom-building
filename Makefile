#
# Makefile -- paravirtual PROM build (cross-compiled SGI PROM for QEMU)
#
# Usage:
#   make toolchain    # Build the MIPS cross-compiler
#   make setup        # Copy source files from IRIX tree
#   make flashbuild   # Build the host flashbuild tool
#   make asm          # Cross-compile assembly files
#   make compile      # Cross-compile C files
#   make link         # Link the PROM binary
#   make all          # Everything (after toolchain + setup)
#   make clean        # Remove build artifacts
#

include toolchain.mk

BUILD_DIR := build
PROM_BIN  := $(BUILD_DIR)/prom.bin
PROM_ELF  := $(BUILD_DIR)/prom.elf

# ── Source file lists ────────────────────────────────────────────────

# Assembly sources
# NOTE: secondary_boot.s removed — SMP secondary CPU boot, not needed here
# NOTE: IP32asm.s removed — CRIME/MACE hardware access, replaced by stubs
# NOTE: mte_asm.s removed — duplicates us_delay (usecdelay.s), write_reg64 (IP32asm.s)
# NOTE: dwdiv.s, lldivrem.s, llcvt.s removed — FPU-dependent, incompatible with -msoft-float
ASM_SRCS := \
    src/fw/csu.s \
    src/lib/usecdelay.s \
    src/libsc/lib/setjmp.s \
    src/libsc/lib/libasm.s \
    src/libsc/ml/btrace.s \
    src/libsc/ml/dwmul.s

# C sources - Tier 1: standalone helpers
TIER1_SRCS := \
    src/libsc/lib/ctype.c \
    src/libsc/lib/atob.c \
    src/libsc/lib/btoa.c \
    src/libsc/lib/strnstuff.c \
    src/libsc/lib/strstuff.c \
    src/libsc/lib/strcasecmp.c \
    src/libsc/lib/malloc.c \
    src/libsc/lib/errputs.c \
    src/libsc/lib/cmn_err.c \
    src/libsc/lib/getenv.c \
    src/libsc/lib/parser.c \
    src/libsc/lib/menu.c \
    src/libsc/lib/stdio.c \
    src/libsc/lib/perror.c \
    src/libsc/lib/stringlist.c \
    src/libsc/lib/mem.c \
    src/libsc/lib/auto.c \
    src/libsc/lib/invfind.c \
    src/libsc/lib/screen.c \
    src/libsc/lib/pause.c \
    src/libsc/lib/expand.c \
    src/libsc/lib/panel.c \
    src/libsc/lib/path.c \
    src/libsc/lib/getpath.c \
    src/libsc/lib/bootname.c \
    src/libsc/lib/large.c \
    src/libsc/lib/range_check.c \
    src/libsc/lib/random.c \
    src/libsc/lib/atobu.c

# C sources - Tier 2: platform library
# NOTE: All TIER2 files removed — CRIME/MACE/MTE/tile/ds2502/UART hardware
# interactions replaced by stubs in pv_stubs.c
TIER2_SRCS :=

# C sources - Tier 3: libsk
# NOTE: flash.c, flashwrite.c removed — flash persistence, replaced by RAM-only env.c
# NOTE: badaddr.c removed — bus probing, replaced by stub (always succeeds)
# NOTE: ds1685.c removed — RTC chip, replaced by stubs
# NOTE: mace_16c550.c removed — MACE serial driver, replaced by stubs
TIER3_SRCS := \
    src/libsk/ml/startup.c \
    src/libsk/ml/env.c \
    src/libsk/fs/fs.c

# C sources - Tier 1b: filesystem support (XFS, EFS, volume header)
FS_SRCS := \
    src/libsc/xfs/xfs.c \
    src/libsc/xfs/xfs_bit.c \
    src/libsc/xfs/xfs_dir.c \
    src/libsc/xfs/xfs_dir2.c \
    src/libsc/xfs/xfs_inode.c \
    src/libsc/fs/efs.c \
    src/libsc/fs/is_vh.c \
    src/libsc/fs/sdvh.c

# C sources - Tier 1c: shell commands
CMD_SRCS := \
    src/libsc/cmd/auto_cmd.c \
    src/libsc/cmd/boot_cmd.c \
    src/libsc/cmd/cat_cmd.c \
    src/libsc/cmd/check_cmd.c \
    src/libsc/cmd/copy_cmd.c \
    src/libsc/cmd/date_cmd.c \
    src/libsc/cmd/dev_cmd.c \
    src/libsc/cmd/dir_cmd.c \
    src/libsc/cmd/echo_cmd.c \
    src/libsc/cmd/go_cmd.c \
    src/libsc/cmd/goto_cmd.c \
    src/libsc/cmd/hinv_cmd.c \
    src/libsc/cmd/ls_cmd.c \
    src/libsc/cmd/memdb_cmd.c \
    src/libsc/cmd/memlist_cmd.c \
    src/libsc/cmd/menu_cmd.c \
    src/libsc/cmd/misc_cmd.c \
    src/libsc/cmd/mount_cmd.c \
    src/libsc/cmd/mrboot_cmd.c \
    src/libsc/cmd/nt_cmd.c \
    src/libsc/cmd/rb_cmd.c \
    src/libsc/cmd/readx_cmd.c \
    src/libsc/cmd/single_cmd.c \
    src/libsc/cmd/type_cmd.c

# C sources - Tier 1d: libsc/ml (machine-independent helpers)
# NOTE: dw.c, lldiv.c, llbit.c, llshift.c removed — SGI 64-bit runtime,
#       not needed by GCC (uses libgcc __muldi3/__udivdi3), and their assembly
#       helpers (dwdiv.s, lldivrem.s, llcvt.s) use FPU ops incompatible with -msoft-float
ML_SRCS := \
    src/libsc/ml/bt.c \
    src/libsc/ml/stack.c

# C sources - Tier 4: firmware core
TIER4_SRCS := \
    src/fw/finit.c \
    src/fw/main.c \
    src/fw/stubs.c

# POST sources (separate for now, may not compile initially)
POST_ASM_SRCS := \
    src/boot/post1.s \
    src/boot/post1csu.s \
    src/boot/post1asmsupt.s

POST_C_SRCS := \
    src/boot/post1mem.c \
    src/boot/post1diags.c \
    src/boot/ser_post.c

# Stub file (grows as we discover missing symbols)
STUB_SRCS := \
    src/fw/pv_stubs.c

# All C sources
C_SRCS := $(TIER1_SRCS) $(FS_SRCS) $(CMD_SRCS) $(ML_SRCS) $(TIER2_SRCS) $(TIER3_SRCS) $(TIER4_SRCS) $(STUB_SRCS)

# All sources
ALL_SRCS := $(ASM_SRCS) $(C_SRCS)

# Object files
ASM_OBJS := $(patsubst src/%.s,$(BUILD_DIR)/%.o,$(ASM_SRCS))
C_OBJS   := $(patsubst src/%.c,$(BUILD_DIR)/%.o,$(C_SRCS))
ALL_OBJS := $(ASM_OBJS) $(C_OBJS)

# ── Phony targets ───────────────────────────────────────────────────

.PHONY: all toolchain setup flashbuild asm compile link clean check-toolchain

all: check-toolchain $(PROM_BIN)
	@echo ""
	@echo "=== paravirtual PROM build complete ==="
	@$(SIZE) $(PROM_ELF)
	@ls -la $(PROM_BIN)

# ── Prerequisites ───────────────────────────────────────────────────

toolchain:
	@echo "=== Building MIPS cross-compiler ==="
	bash scripts/build-toolchain.sh

setup:
	@echo "=== Copying IRIX source files ==="
	bash scripts/setup-sources.sh

check-toolchain:
	@if [ ! -x "$(CC)" ]; then \
		echo "ERROR: Cross-compiler not found: $(CC)"; \
		echo "Run 'make toolchain' first."; \
		exit 1; \
	fi

# ── flashbuild host tool ────────────────────────────────────────────

FLASHBUILD := $(BUILD_DIR)/tools/flashbuild

flashbuild: $(FLASHBUILD)

$(FLASHBUILD): tools/flashbuild/main.c tools/flashbuild/buildFlash.c \
               tools/flashbuild/elfFiles.c tools/flashbuild/writeHex.c \
               tools/flashbuild/fb.h
	@mkdir -p $(BUILD_DIR)/tools
	$(HOSTCC) -o $@ \
		tools/flashbuild/main.c \
		tools/flashbuild/buildFlash.c \
		tools/flashbuild/elfFiles.c \
		tools/flashbuild/writeHex.c \
		-I tools/flashbuild \
		-I include/ip32 \
		-D_LANGUAGE_C \
		-Wno-implicit-function-declaration \
		-Wno-format

# ── Assembly compilation ────────────────────────────────────────────

asm: check-toolchain $(ASM_OBJS)
	@echo "=== Assembly files compiled ==="

# Assembly files use #include and macros, need preprocessing (-x assembler-with-cpp)
$(BUILD_DIR)/%.o: src/%.s
	@mkdir -p $(dir $@)
	$(CC) $(ASFLAGS) -x assembler-with-cpp -c -o $@ $<

# ── C compilation ───────────────────────────────────────────────────

compile: check-toolchain $(C_OBJS)
	@echo "=== C files compiled ==="

$(BUILD_DIR)/%.o: src/%.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c -o $@ $<

# ── Linking ─────────────────────────────────────────────────────────

link: $(PROM_BIN)

$(PROM_ELF): $(ALL_OBJS) $(LDSCRIPT)
	$(LD) $(LDFLAGS) -T $(LDSCRIPT) -o $@ $(ALL_OBJS) $(LIBGCC)
	@echo "=== ELF linked: $@ ==="

$(PROM_BIN): $(PROM_ELF)
	$(OBJCOPY) -O binary $< $@
	@# Pad to 512KB
	@FSIZE=$$(stat -f%z "$@" 2>/dev/null || stat -c%s "$@" 2>/dev/null); \
	if [ "$$FSIZE" -lt 524288 ]; then \
		dd if=/dev/zero bs=1 count=$$((524288 - $$FSIZE)) >> $@ 2>/dev/null; \
	fi
	@echo "=== PROM binary: $@ (512KB) ==="

# ── Utilities ───────────────────────────────────────────────────────

disasm: $(PROM_ELF)
	$(OBJDUMP) -d $< > $(BUILD_DIR)/prom.dis
	@echo "Disassembly: $(BUILD_DIR)/prom.dis"

symbols: $(PROM_ELF)
	$(NM) -n $< > $(BUILD_DIR)/prom.sym
	@echo "Symbol table: $(BUILD_DIR)/prom.sym"

# ── Cleaning ────────────────────────────────────────────────────────

clean:
	rm -rf $(BUILD_DIR)

# ── Per-file compilation (for iterative development) ────────────────

# Try compiling a single file:
#   make try-compile FILE=src/libsc/lib/ctype.c
try-compile: check-toolchain
	@if [ -z "$(FILE)" ]; then echo "Usage: make try-compile FILE=src/foo.c"; exit 1; fi
	@mkdir -p $(BUILD_DIR)/try
	$(CC) $(CFLAGS) -c -o $(BUILD_DIR)/try/test.o $(FILE)
	@echo "OK: $(FILE)"

try-asm: check-toolchain
	@if [ -z "$(FILE)" ]; then echo "Usage: make try-asm FILE=src/foo.s"; exit 1; fi
	@mkdir -p $(BUILD_DIR)/try
	$(CC) $(ASFLAGS) -x assembler-with-cpp -c -o $(BUILD_DIR)/try/test.o $(FILE)
	@echo "OK: $(FILE)"

# Show what would be compiled
list-sources:
	@echo "=== Assembly sources ==="
	@for f in $(ASM_SRCS); do echo "  $$f"; done
	@echo ""
	@echo "=== C sources (Tier 1: libsc helpers) ==="
	@for f in $(TIER1_SRCS); do echo "  $$f"; done
	@echo ""
	@echo "=== C sources (Tier 2: platform lib) ==="
	@for f in $(TIER2_SRCS); do echo "  $$f"; done
	@echo ""
	@echo "=== C sources (Tier 3: libsk) ==="
	@for f in $(TIER3_SRCS); do echo "  $$f"; done
	@echo ""
	@echo "=== C sources (Tier 4: firmware) ==="
	@for f in $(TIER4_SRCS); do echo "  $$f"; done
	@echo ""
	@echo "=== Stubs ==="
	@for f in $(STUB_SRCS); do echo "  $$f"; done
