/*
 * irix_compat.h -- Master compatibility shim for IRIX → GCC cross-compilation
 *
 * This header bridges differences between SGI MIPSpro and GCC:
 * - Defines language/environment macros expected by IRIX headers
 * - Provides address space macros (K0BASE, K1BASE, PHYS_TO_K0, etc.)
 * - Stubs out MIPSpro-specific constructs
 *
 * Include this via -include irix_compat.h in CFLAGS so it's always available.
 */
#ifndef __IP54_IRIX_COMPAT_H__
#define __IP54_IRIX_COMPAT_H__

/*
 * SGI type definitions (__int32_t, __uint64_t, __psunsigned_t, etc.)
 * Must be included early so all downstream headers can use these types.
 */
#include "sgidefs.h"

/*
 * Environment identification macros expected by IRIX standalone code.
 * _LANGUAGE_C / _LANGUAGE_ASSEMBLY are set via -D flags in the Makefile.
 */
#ifndef _STANDALONE
#define _STANDALONE 1
#endif

#ifndef _KERNEL
#define _KERNEL 1
#endif

#ifndef IP32
#define IP32 1
#endif

/* R4000-class processor (IP32 uses R5000/R10000/R12000) */
#ifndef R4000
#define R4000 1
#endif

#ifndef R10000
#define R10000 0
#endif

/* Big-endian */
#ifndef _MIPSEB
#define _MIPSEB 1
#endif

/*
 * MIPS address space macros
 * These are fundamental to all MIPS kernel/firmware code.
 */
#ifndef K0BASE
#define K0BASE      0x80000000  /* kseg0: cached, unmapped */
#define K1BASE      0xA0000000  /* kseg1: uncached, unmapped */
#define K2BASE      0xC0000000  /* kseg2/ksseg: mapped */
#define KUBASE      0x00000000  /* kuseg: user space */
#define KUSIZE      0x80000000
#define K0SIZE      0x20000000
#define K1SIZE      0x20000000
#define K2SIZE      0x40000000
#endif

#ifndef PHYS_TO_K0
#define PHYS_TO_K0(x)   ((unsigned)(x) | K0BASE)
#define PHYS_TO_K1(x)   ((unsigned)(x) | K1BASE)
#define K0_TO_PHYS(x)   ((unsigned)(x) & 0x1FFFFFFF)
#define K1_TO_PHYS(x)   ((unsigned)(x) & 0x1FFFFFFF)
#define K0_TO_K1(x)     ((unsigned)(x) | 0x20000000)
#define K1_TO_K0(x)     ((unsigned)(x) & ~0x20000000)
#define IS_KSEG0(x)     (((unsigned)(x) & 0xE0000000) == K0BASE)
#define IS_KSEG1(x)     (((unsigned)(x) & 0xE0000000) == K1BASE)
#define IS_KSEG2(x)     (((unsigned)(x) & 0xC0000000) == K2BASE)
#define IS_KUSEG(x)     (((unsigned)(x) >> 31) == 0)
#endif

/*
 * IP54 QEMU target: IP32 (O2) has RAM at physical 0x00000000.
 * PHYS_RAMBASE is defined in IP32.h as 0x00000000.
 */

/*
 * GCC attribute equivalents for MIPSpro pragmas
 */
#define __packed    __attribute__((packed))

/*
 * MIPSpro #pragma weak → GCC __attribute__((weak))
 * (Applied per-symbol in source as needed)
 */

/*
 * Volatile register idiom: MIPSpro uses "volatile" as a storage class
 * for registers that must be preserved across calls. GCC doesn't
 * support this syntax. In standalone PROM context, we can ignore it.
 */

/*
 * SGI paddr_t - physical address type (32-bit in O32)
 */
#ifndef _SYS_TYPES_H
typedef unsigned long paddr_t;
typedef unsigned int  size_t;
typedef int           ssize_t;
typedef long          off_t;
typedef int           pid_t;
typedef unsigned int  uint;
typedef unsigned short ushort;
typedef unsigned char uchar;
typedef unsigned char u_char;
typedef unsigned short u_short;
typedef unsigned int  u_int;
typedef unsigned long u_long;
typedef unsigned long ulong;
typedef int           bool_t;
typedef long          time_t;
typedef unsigned int  uint_t;
typedef unsigned long ulong_t;
typedef int           int_t;
typedef unsigned char uchar_t;
typedef unsigned short ushort_t;
typedef char *        caddr_t;
typedef long          daddr_t;
typedef int           cnt_t;
typedef unsigned int  inst_t;      /* MIPS instruction type */
typedef unsigned int  machreg_t;   /* machine register type */
typedef unsigned long k_machreg_t;
typedef unsigned long long iopaddr_t;
typedef int           toid_t;      /* timeout ID type */
typedef int           lock_t;      /* kernel lock type (stub) */
typedef int           pfn_t;       /* page frame number type */
typedef int           cpuid_t;     /* CPU ID type */
typedef unsigned int  dev_t;       /* device number type */
typedef short         nasid_t;     /* node/ASIC ID (SN0 multi-node) */
typedef short         cnodeid_t;   /* compact node ID */
/* sema_t defined in sys/sema.h when included */
typedef unsigned char unchar;     /* alias used in some kernel headers */
typedef unsigned long cell_t;     /* kernel cell type */
typedef int           bitnum_t;   /* bit number type */
typedef int           bitlen_t;   /* bit length type */

/* ABI translation types (used in ktime.h etc.) */
typedef long          app32_long_t;
typedef int           app32_int_t;
typedef long long     app64_long_t;
typedef int           app64_int_t;
typedef unsigned long cpumask_t;   /* CPU bitmask */
typedef unsigned long k_sigset_t;  /* kernel signal set */
typedef unsigned int  uid_t;       /* user ID type */
typedef unsigned int  gid_t;       /* group ID type */
typedef int           processorid_t; /* processor ID */
typedef int           pl_t;        /* priority level (SPL) */
typedef unsigned int  major_t;     /* device major number */
typedef unsigned int  minor_t;     /* device minor number */
typedef unsigned int  app32_ptr_t; /* 32-bit ABI pointer */
typedef int           graph_vertex_place_t; /* hwgraph traversal */

/* Additional types needed by kernel headers (XFS, vnode, stat, uuid) */
typedef enum { B_FALSE, B_TRUE } boolean_t;
typedef short         o_dev_t;    /* old 16-bit device type */
/* u_intN_t aliases (from sys/types.h end section) */
#ifndef u_int8_t
typedef unsigned char  u_int8_t;
typedef unsigned short u_int16_t;
typedef __uint32_t     u_int32_t;
#define u_int8_t u_int8_t
#endif
typedef char *uvaddr_t;            /* user virtual address */
typedef __uint64_t k_fpreg_t;      /* FPU register */
typedef unsigned long mode_t;
typedef unsigned long nlink_t;
typedef unsigned long ino_t;
typedef __uint64_t    ino64_t;
typedef __int64_t     off64_t;
typedef __int64_t     blkcnt_t;
typedef __int64_t     blkcnt64_t;
typedef __uint64_t    fsblkcnt_t;
typedef __uint64_t    fsfilcnt_t;
typedef unsigned long pgno_t;
typedef __int64_t     prid_t;
typedef __int64_t     ash_t;
typedef int           credid_t;
typedef unsigned char mprot_t;
typedef int           tid_t;
typedef unsigned int  vertex_hdl_t; /* hwgraph vertex handle (stub) */
typedef int           graph_edge_place_t;
typedef int           arbitrary_info_t;
typedef unsigned int  k_fltset_t;

/* Prevent IP32k.c from redefining uint32_t etc. */
#define __inttypes_INCLUDED 1
#define _SYS_TYPES_H  /* prevent real types.h from being included */
/* Define guards for other types.h-provided things so real types.h is skipped cleanly */
#define _OFF64_T
#define _OFF_T
#define _INO_T
#define _SIZE_T
#define _SSIZE_T
#define _TIME_T
#define _CLOCK_T
#define _WCHAR_T
/* Define POSIX/XOPEN guards so boolean_t doesn't get re-evaluated from types.h */
#define _NO_POSIX 1
#define _NO_XOPEN4 1
#define _NO_XOPEN5 1
#endif

/*
 * NULL
 */
#ifndef NULL
#define NULL ((void *)0)
#endif

/*
 * stdio stubs — standalone code references stderr/stdout but we
 * route everything through printf() which maps to our polled UART.
 */
#ifndef stderr
#define stderr  ((void*)0)   /* ignored in standalone */
#define stdout  ((void*)0)
#define stdin   ((void*)0)
#endif
#ifndef NULL
#endif

/*
 * Coprocessor 0 register names used by IRIX assembly/C code
 */
#ifndef C0_SR
#define C0_SR       $12    /* Status Register */
#define C0_CAUSE    $13    /* Cause Register */
#define C0_EPC      $14    /* Exception Program Counter */
#define C0_CONFIG   $16    /* Configuration Register */
#define C0_LLADDR   $17    /* Load Linked Address */
#define C0_BADVADDR $8     /* Bad Virtual Address */
#define C0_COUNT    $9     /* Count Register */
#define C0_COMPARE  $11    /* Compare Register */
#define C0_PRID     $15    /* Processor Revision ID */
#define C0_TAGLO    $28    /* TagLo */
#define C0_TAGHI    $29    /* TagHi */
#define C0_ERROR_EPC $30   /* Error EPC */

/* TLB-related */
#define C0_INX      $0     /* Index */
#define C0_RAND     $1     /* Random */
#define C0_TLBLO    $2     /* TLB EntryLo0 */
#define C0_TLBLO_1  $3     /* TLB EntryLo1 */
#define C0_CTXT     $4     /* Context */
#define C0_PGMASK   $5     /* PageMask */
#define C0_TLBWIRED $6     /* Wired */
#define C0_TLBHI    $10    /* TLB EntryHi */

/* Operations */
#define C0_WRITER   0x02   /* TLB Write Random */
#define C0_READ     0x01   /* TLB Read */
#define C0_PROBE    0x08   /* TLB Probe */
#endif

/*
 * Status Register bits
 */
#ifndef SR_CU0
#define SR_CU0      0x10000000
#define SR_CU1      0x20000000
#define SR_BEV      0x00400000
#define SR_DE       0x00010000
#define SR_KX       0x00000080
#define SR_SX       0x00000040
#define SR_UX       0x00000020
#define SR_ERL      0x00000004
#define SR_EXL      0x00000002
#define SR_IE       0x00000001
#define SR_IMASK    0x0000FF00
#endif

/*
 * Suppress some warnings from IRIX code patterns
 */
#pragma GCC diagnostic ignored "-Wimplicit-function-declaration"
#pragma GCC diagnostic ignored "-Wimplicit-int"
#pragma GCC diagnostic ignored "-Wint-conversion"

/*
 * Function exclusion guards: disable IRIX implementations that depend on
 * hardware we don't have (e.g., flash ROM). Stubs in ip54_stubs.c provide
 * replacements.
 */
#define IP54_STUB_GETVERSION  /* getversion: use stub instead of flash-reading version */

#endif /* __IP54_IRIX_COMPAT_H__ */
