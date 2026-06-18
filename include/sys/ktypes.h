/* sys/ktypes.h -- stub for standalone PROM build */
#ifndef __SYS_KTYPES_H__
#define __SYS_KTYPES_H__
/* Kernel type aliases - most are already in irix_compat.h */
#endif
/* Kernel ABI type aliases needed by dirent.h */
typedef unsigned long app32_ulong_t;
typedef unsigned int  app32_uint_t;
typedef long          irix5_off_t;    /* IRIX5 32-bit file offset */
#define ABI_IS_IRIX5(abi)  0
#define ABI_IRIX5          0
#define ABI_IRIX5_64       1
#define FDIRENT64          0
