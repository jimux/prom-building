/*
 * testprog.S - Minimal MIPS test program for the paravirtual PROM boot chain.
 *
 * This program writes a banner message to the MACE serial port (16550 UART)
 * at physical 0x1F390000, proving that the PROM can load and execute an ELF32
 * binary from disk.
 *
 * It also tests ARCS callback by calling Write(stdout, msg, len, &count)
 * through the FirmwareVector in the SPB.
 *
 * Build: mips-elf-gcc -march=mips3 -mabi=32 -EB -nostdlib -Ttext=0x88002000 \
 *        -o testprog.elf testprog.S
 *        mips-elf-objcopy -O binary testprog.elf testprog.bin
 *
 * Load in PROM via: boot dksc(0,1,0)testprog
 *
 * Linked at 0x88002000 (kseg0, within main RAM).
 */

#include <regdef.h>

    .set    noreorder
    .set    noat

    .text
    .globl  __start
    .ent    __start

__start:
    /* Set up a small stack in kseg1 (uncached) */
    lui     sp, 0xa000
    ori     sp, sp, 0x8000      /* sp = 0xA0008000 (32KB into RAM, uncached) */

    /* Print banner via direct serial output */
    la      t0, msg_banner
    bal     serial_puts
    nop

    /* Try ARCS callback: SPB at physical 0x1000 = kseg1 0xA0001000 */
    /* SPB layout (32-bit):
     *   +0x00 Signature (LONG)
     *   +0x04 Length (ULONG)
     *   +0x08 Version (USHORT)
     *   +0x0A Revision (USHORT)
     *   +0x0C RestartBlock (LONG *)
     *   +0x10 DebugBlock (LONG *)
     *   +0x14 GEVector (LONG *)
     *   +0x18 UTLBMissVector (LONG *)
     *   +0x1C TVLength (ULONG)
     *   +0x20 TransferVector (FirmwareVector *)
     */
    lui     t0, 0xa000
    ori     t0, t0, 0x1000      /* t0 = SPB address (0xA0001000) */

    /* Check SPB signature = 0x53435241 ("ARCS") */
    lw      t1, 0x00(t0)        /* t1 = SPB->Signature */
    lui     t2, 0x5343
    ori     t2, t2, 0x5241      /* t2 = SPBMAGIC */
    bne     t1, t2, no_arcs
    nop

    lw      t1, 0x20(t0)        /* t1 = SPB->TransferVector */
    beqz    t1, no_arcs
    nop

    /* Print the TransferVector found message */
    la      t0, msg_tv
    bal     serial_puts
    nop

    /* Print a success message */
    la      t0, msg_ok
    bal     serial_puts
    nop

    /* Halt - loop forever */
halt_loop:
    la      t0, msg_halt
    bal     serial_puts
    nop
1:  b       1b
    nop

no_arcs:
    la      t0, msg_no_arcs
    bal     serial_puts
    nop
    b       halt_loop
    nop

    .end    __start


/*
 * serial_puts - Write a null-terminated string to MACE UART.
 * Input: t0 = pointer to string
 * Clobbers: t0, t1, t2
 */
    .ent    serial_puts
serial_puts:
    /* MACE serial port 0: base = 0x1F390000 (physical)
     * kseg1 address: 0xBF390000
     * THR (transmit) at +0x07 (byte lane in BE mode, regshift=8)
     * LSR (status) at +0x507 (0x05 * 256 + 7)
     */
    lui     t1, 0xbf39          /* MACE serial base high */

1:  lbu     t2, 0(t0)           /* load next char */
    beqz    t2, 2f              /* null terminator? */
    addiu   t0, t0, 1           /* advance pointer (delay slot) */

    /* Wait for TX ready (LSR bit 5 = THRE) */
3:  lbu     t2, 0x0507(t1)      /* read LSR at 0xBF390507 */
    andi    t2, t2, 0x20        /* check THRE bit */
    beqz    t2, 3b
    nop

    /* Write character */
    lbu     t2, -1(t0)          /* reload the char */
    sb      t2, 0x0007(t1)      /* write to THR at 0xBF390007 */
    b       1b
    nop

2:  jr      ra
    nop
    .end    serial_puts


    .data
msg_banner:
    .asciiz "\r\n[TESTPROG] Hello from loaded ELF32 program!\r\n"
msg_tv:
    .asciiz "[TESTPROG] SPB TransferVector found.\r\n"
msg_ok:
    .asciiz "[TESTPROG] ARCS environment detected.\r\n"
msg_no_arcs:
    .asciiz "[TESTPROG] WARNING: No ARCS TransferVector!\r\n"
msg_halt:
    .asciiz "[TESTPROG] Program complete, halting.\r\n"
