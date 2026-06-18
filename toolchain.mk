#
# toolchain.mk -- Cross-compiler paths and flags for IP54 PROM build
#

# Cross-compiler prefix
CROSS_PREFIX ?= $(HOME)/cross/mips-elf
CROSS        := $(CROSS_PREFIX)/bin/mips-elf-

CC      := $(CROSS)gcc
AS      := $(CROSS)as
LD      := $(CROSS)ld
AR      := $(CROSS)ar
OBJCOPY := $(CROSS)objcopy
OBJDUMP := $(CROSS)objdump
SIZE    := $(CROSS)size
NM      := $(CROSS)nm

# Host compiler (for build tools like flashbuild)
HOSTCC  := cc

# Project paths
PROJECT_DIR := $(dir $(lastword $(MAKEFILE_LIST)))
COMPAT_DIR  := $(PROJECT_DIR)compat
INCLUDE_DIR := $(PROJECT_DIR)include
IP32_INC    := $(PROJECT_DIR)include/ip32
SRC_DIR     := $(PROJECT_DIR)src

#
# Include path ordering is critical:
# 1. compat/ -- our sgidefs.h, asm.h, regdef.h override IRIX versions
# 2. include/ip32/ -- IP32prom-specific headers (has its own flash.h, trace.h)
# 3. include/ -- stand/arcs headers (libsc.h, libsk.h, fault.h, etc.)
# 4. include/sys/ -- kernel headers (via <sys/foo.h>)
#
INCLUDES := -I$(COMPAT_DIR) \
            -I$(IP32_INC) \
            -I$(INCLUDE_DIR) \
            -I$(INCLUDE_DIR)/sys

#
# Compiler flags
#
# -march=mips3    : MIPS III ISA (R4000-class, 64-bit registers)
# -mabi=32        : O32 ABI (32-bit pointers, 32-bit calling convention)
# -EB             : Big-endian (SGI convention)
# -G 0            : No GP-relative addressing (matches SGI convention)
# -ffreestanding  : No hosted environment assumptions
# -nostdlib       : Don't link standard libraries
# -nostartfiles   : Don't link crt0
# -mno-abicalls   : No PIC/SVR4 ABI call sequences (bare-metal)
# -fno-pic        : No position-independent code
#
ARCH_FLAGS := -march=mips3 -mabi=32 -EB -G 0 -mno-abicalls -fno-pic -msoft-float

FREESTANDING_FLAGS := -ffreestanding -nostdlib -nostartfiles

# Defines passed to both C and assembly
DEFINES := -D_STANDALONE -D_KERNEL -DIP32 -DR4000 -D_MIPSEB \
           -D_PAGESZ=16384 -D_LANGUAGE_C

# Assembly-specific defines (override _LANGUAGE_C)
ASM_DEFINES := -D_STANDALONE -D_KERNEL -DIP32 -DR4000 -D_MIPSEB \
               -D_PAGESZ=16384 -D_LANGUAGE_ASSEMBLY

# Warning flags - relaxed for IRIX compatibility
WARNINGS := -Wall -Wno-implicit-function-declaration -Wno-implicit-int \
            -Wno-int-conversion -Wno-pointer-sign -Wno-unused-variable \
            -Wno-missing-braces -Wno-parentheses

# Optimization
OPT := -O1

# Combined flags
CFLAGS := $(ARCH_FLAGS) $(FREESTANDING_FLAGS) $(OPT) $(WARNINGS) \
          $(DEFINES) $(INCLUDES) \
          -include $(COMPAT_DIR)/irix_compat.h

ASFLAGS := $(ARCH_FLAGS) $(ASM_DEFINES) $(INCLUDES)

LDFLAGS := -nostdlib -static -EB

# libgcc provides __udivdi3, __umoddi3, etc.
LIBGCC := $(shell $(CC) $(ARCH_FLAGS) -print-libgcc-file-name)

# Linker script
LDSCRIPT := $(PROJECT_DIR)link/prom.ld
