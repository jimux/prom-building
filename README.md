# prom-building — from-source SGI PROM build tree

Cross-compiled SGI PROM source + build harness, producing a complete
512 KB firmware image built from SGI's IP32prom-derived source. It was
written for an earlier paravirtual QEMU machine that has since been
retired, so **the image does not currently boot any machine**.

It is kept as the reserve "real ROM image" substrate for virtuix/IP55
(master plan Track C, `progress_notes/ip55/master_plan/03-prom-ip55.md`):
today virtuix's firmware is the host-side paravirtual ARCS inside QEMU
(Mode K / Mode C), and this tree is the reference if a real ROM is ever
needed. Per Track C, do not port it to virtuix as a first step.

## Layout

```
src/
  fw/        Firmware proper (loader, ARCS, kernel-loader, paravirtual stubs)
  boot/      Secondary bootloader
  lib/       Shared PROM libraries (libsk, libsc, etc.)
  libsc/     Shared C runtime
  libsk/     Shared kernel-side runtime helpers
include/     PROM headers (mostly from SGI's IP32prom source plus local additions)
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
make link         # Link the PROM binary -> build/prom.bin
make all          # Everything (after toolchain + setup)
make clean        # Remove build artifacts
```

The result is `build/prom.bin`.

## Kernel-symbol patches

`src/fw/pv_stubs.c` contains the kernel-symbol resolver (`kern_sym()`)
and the PROM patches it applied to the retired machine's kernel image at
load time (fault trampolines, null guards, device-probe stubs). They name
symbols of that retired kernel, so treat them as worked examples of the
technique rather than patches that apply to any current kernel.

## Related repos

- **qemu-sgi-repo** — the QEMU fork (virtuix, indy and the other SGI machines)
- **qemu-sgi**      — umbrella workspace (build pipelines, tests,
                      progress notes, MCP server)
