/*
 * prom.ld -- GNU ld linker script for paravirtual PROM
 *
 * Single-stage flat PROM image for QEMU emulation.
 * Loaded at physical 0x1FC00000, mapped via kseg1 at 0xBFC00000.
 *
 * Memory layout:
 *   0xBFC00000 - 0xBFC7FFFF : PROM (512KB, kseg1 uncached)
 *   0x80000000 - 0x83FFFFFF : RAM  (kseg0 cached, physical 0x00000000)
 *
 * IP32 (O2) RAM starts at physical 0x00000000, so kseg0 base
 * is 0x80000000.
 *
 * Data/BSS placed near top of 64MB RAM (0x83F00000 = physical
 * 0x3F00000) to avoid being overwritten when loading kernels.
 * The IRIX 6.3 kernel loads at physical 0x2000 through ~0x24000,
 * so the old +1MB placement was destroyed on kernel load.
 *
 * The PROM entry point is at 0xBFC00000 (MIPS reset vector).
 */

OUTPUT_FORMAT("elf32-bigmips")
OUTPUT_ARCH(mips)
ENTRY(fwEntry)

MEMORY
{
    /* PROM mapped at kseg1 uncached address */
    PROM (rx)  : ORIGIN = 0xBFC00000, LENGTH = 512K

    /* RAM at kseg0 cached address, near top of 64MB to avoid kernel overlap */
    RAM  (rwx) : ORIGIN = 0x83F00000, LENGTH = 1M
}

SECTIONS
{
    /* ── PROM (ROM) sections ─────────────────────────────────── */

    .text : {
        _ftext = .;

        /* Reset vector entry point must be first */
        *(.text.entry)

        /* Exception vectors at known offsets from 0xBFC00000 */
        /* BEV=1 vectors: TLB Refill at +0x200, XTLB at +0x280,
         * Cache Error at +0x300, General at +0x380 */

        *(.text.vectors)
        *(.text)
        *(.text.*)

        _etext = .;
    } > PROM

    .rodata : {
        *(.rodata)
        *(.rodata.*)
        *(.rodata1)
        *(.sdata2)
        *(.sdata2.*)
    } > PROM

    /* End of ROM content marker */
    _erom = .;

    /* ── RAM sections (loaded from ROM, copied at startup) ─── */

    .data : AT(_erom) {
        _fdata = .;
        *(.data)
        *(.data.*)
        *(.sdata)
        *(.sdata.*)
        _edata = .;
    } > RAM

    /* Load address in ROM for data copy */
    _data_load = LOADADDR(.data);

    .sbss (NOLOAD) : {
        _fbss = .;
        *(.sbss)
        *(.sbss.*)
        *(.scommon)
    } > RAM

    .bss (NOLOAD) : {
        *(.bss)
        *(.bss.*)
        *(COMMON)
        _end = .;
    } > RAM

    /* PROM stack: above BSS (which ends at ~0x83F66F38), with padding.
     * Must be > _end so that the BSS-zeroing formula (PROM_STACK - firstBss)
     * produces a positive size.  Use 0x83FC0000 (well above _end, within
     * the 1MB RAM window at 0x83F00000-0x83FFFFFF). */
    _stack_top = 0x83FC0000;
    PROM_STACK = 0x83FC0000;

    /DISCARD/ : {
        *(.MIPS.abiflags)
        *(.gnu.attributes)
        *(.pdr)
        *(.comment)
        *(.note.*)
        *(.reginfo)
        *(.options)
        *(.eh_frame)
        *(.eh_frame_hdr)
    }
}
