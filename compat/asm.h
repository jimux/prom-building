/*
 * asm.h -- GCC/gas-compatible replacement for SGI's sys/asm.h
 *
 * Provides LEAF/NESTED/END and related macros for GNU assembler.
 * The original uses MIPSpro assembler syntax which is mostly compatible
 * with gas, but we include this to ensure our sgidefs.h gets used
 * and to provide any needed fixups.
 *
 * Strategy: include the real IRIX asm.h (which we copied to include/sys/asm.h)
 * after ensuring sgidefs.h is resolved to our compat version.
 */
#ifndef __PVPROM_COMPAT_ASM_H__
#define __PVPROM_COMPAT_ASM_H__

/* Our sgidefs.h must be found first via -I ordering */
#include "sgidefs.h"

/* Now include the real IRIX asm.h which has LEAF/NESTED/END/etc. */
#include <sys/asm.h>

#endif /* __PVPROM_COMPAT_ASM_H__ */
