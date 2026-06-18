/*
 * sgidefs.h -- GCC-compatible replacement for SGI's sgidefs.h
 *
 * Maps SGI internal types and compiler constants to C99/GCC equivalents.
 * The original sgidefs.h relies on MIPSpro compiler builtins; this version
 * provides the same definitions using standard C99 types.
 */
#ifndef __SGIDEFS_H__
#define __SGIDEFS_H__

/*
 * Instruction Set Architecture constants
 */
#define _MIPS_ISA_MIPS1  1
#define _MIPS_ISA_MIPS2  2
#define _MIPS_ISA_MIPS3  3
#define _MIPS_ISA_MIPS4  4

/*
 * Subprogram Interface Model (ABI) constants
 */
#define _MIPS_SIM_ABI32   1    /* O32 */
#define _MIPS_SIM_NABI32  2    /* N32 */
#define _MIPS_SIM_ABI64   3    /* N64 */

/* Aliases used in some IRIX headers */
#ifndef _ABIO32
#define _ABIO32   _MIPS_SIM_ABI32
#endif
#ifndef _ABIN32
#define _ABIN32   _MIPS_SIM_NABI32
#endif
#ifndef _ABI64
#define _ABI64    _MIPS_SIM_ABI64
#endif

/*
 * Target configuration: MIPS III ISA, O32 ABI, 32-bit pointers
 * These match our -march=mips3 -mabi=32 compiler flags.
 */
#ifndef _MIPS_ISA
#define _MIPS_ISA    _MIPS_ISA_MIPS3
#endif
#ifndef _MIPS_SIM
#define _MIPS_SIM    _MIPS_SIM_ABI32
#endif
#ifndef _MIPS_SZINT
#define _MIPS_SZINT  32
#endif
#ifndef _MIPS_SZLONG
#define _MIPS_SZLONG 32
#endif
#ifndef _MIPS_SZPTR
#define _MIPS_SZPTR  32
#endif

/*
 * C-only type definitions (skip for assembly)
 */
#ifndef _LANGUAGE_ASSEMBLY
#ifndef __ASSEMBLER__

#include <stdint.h>

/* SGI internal integer types -> C99 */
typedef int32_t    __int32_t;
typedef uint32_t   __uint32_t;
typedef int64_t    __int64_t;
typedef uint64_t   __uint64_t;

/* Pointer-sized integer types (32-bit in O32) */
typedef intptr_t   __psint_t;
typedef uintptr_t  __psunsigned_t;

/* Scaling integer types (same as pointer-sized for O32) */
typedef intptr_t   __scint_t;
typedef uintptr_t  __scunsigned_t;

#endif /* !__ASSEMBLER__ */
#endif /* !_LANGUAGE_ASSEMBLY */

#endif /* __SGIDEFS_H__ */
