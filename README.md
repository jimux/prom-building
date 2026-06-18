# prom-building — IP54 PROM build tree

Cross-compiled SGI PROM source + build harness, producing the firmware
image that boots `qemu-system-mips64 -M sgi-ip54`. Developed alongside
[qemu-sgi](../) and [irix-ip54](../irix-ip54/) — driver-side changes in
irix-ip54 and device-side changes in `qemu-sgi-repo/hw/` typically need
PROM-side companion patches here (kernel-symbol resolution, fault
trampolines, PROM-side patches into the kernel image).

## Layout

```
src/
  fw/        Firmware proper (loader, ARCS, kernel-loader, IP54 stubs)
  boot/      Secondary bootloader
  lib/       Shared PROM libraries (libsk, libsc, etc.)
  libsc/     Shared C runtime
  libsk/     Shared kernel-side runtime helpers
include/     PROM headers (mostly from SGI's IP32prom source plus IP54 additions)
compat/      Compat shims for building outside the original IRIX environment
scripts/     setup-sources.sh, build-toolchain.sh, build-all.sh, find-missing-headers.sh
tools/       Host-side tools (flashbuild — assembles the final PROM .bin image)
link/        Linker scripts
tests/       Smoke tests
Makefile     Top-level build
toolchain.mk Cross-toolchain configuration (MIPS bare-metal GCC)
```

## Build

```
make toolchain    # Build the MIPS cross-compiler (binutils + GCC)
make setup        # Copy source files from IRIX tree
make flashbuild   # Build the host flashbuild tool
make asm          # Cross-compile assembly files
make compile      # Cross-compile C files
make link         # Link the PROM binary -> build/ip54.bin
make all          # Everything (after toolchain + setup)
make clean        # Remove build artifacts
```

The resulting `build/ip54.bin` is the PROM image consumed by QEMU:

```
qemu-system-mips64 -M sgi-ip54 -bios path/to/ip54.bin -m 256M ...
```

For the IP54-specific bits in `src/fw/ip54_stubs.c` (kernel-symbol
resolution, fault trampolines, the PROM patches into `/unix.new`), see
the architecture writeups under `qemu-sgi/progress_notes/ip54/`.

## Kernel-symbol patches

`src/fw/ip54_stubs.c` contains the kernel-symbol resolver and the PROM
patches applied at load time. Many of those patches reference addresses
that drift across kernel rebuilds (see qemu-sgi/progress_notes/ip54/
dt_desktop_zone_corruption.md for the long history). The runtime
resolver (kern_sym()) makes most patches drift-tolerant — but a handful
of address-based patches still need to be kept in sync with the
booting `/unix.new`.

## Related repos

- **qemu-sgi-repo** — QEMU fork w/ the IP54 paravirtual device models
- **irix-ip54**     — IRIX kernel-side drivers + sysgen
- **qemu-sgi**      — umbrella orchestrator (build pipelines, tests,
                      progress notes, MCP server)
