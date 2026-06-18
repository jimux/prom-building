/*
 * sys/fpu.h -- Minimal stub for standalone PROM build
 * FPU status/control register definitions.
 */
#ifndef __SYS_FPU_H__
#define __SYS_FPU_H__

/* FPU Control/Status Register bits */
#define CSR_EXCEPT      0x0003f000  /* Cause bits */
#define CSR_ENABLE      0x00000f80  /* Enable bits */
#define CSR_FLAGS       0x0000007c  /* Flag bits */

#endif /* __SYS_FPU_H__ */
