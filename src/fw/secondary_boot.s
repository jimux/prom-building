/* secondary_boot.S - Spinloop for secondary CPUs */
#include <sys/asm.h>
#include <sys/regdef.h>

    .text
    .set noreorder
    .align 4
    .globl secondary_boot
    .ent secondary_boot
secondary_boot:
    /* Disable interrupts */
    mfc0    t0, $12     # CP0_STATUS
    li      t1, ~1
    and     t0, t0, t1
    mtc0    t0, $12

1:  wait                # Wait for interrupt (IPI)
    nop
    b       1b
    nop
    .end secondary_boot
