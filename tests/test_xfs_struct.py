"""
test_xfs_struct.py — Unit tests for XFS superblock struct layout and disk format.

The XFS on-disk superblock format is fixed (see xfs_sb.h comments):
  sb_magicnum   at byte   0  (uint32 big-endian)
  sb_dblocks    at byte   8  (uint64 big-endian, always disk-based type)
  sb_uuid       at byte  32  (16-byte char array)
  sb_logstart   at byte  48  (uint64, disk-based)
  sb_rootino    at byte  56  (xfs_ino_t = uint64, unconditional)
  sb_versionnum at byte 100  (uint16 big-endian)

Our cross-compiled xfs_sb_t struct MUST match this layout for
bcopy(disk_buf, sbp, sizeof(xfs_sb_t)) to work correctly in _xfs_checkfs.

Root cause under investigation: with -mabi=32 (O32 ABI), does GCC place
uint64_t fields at 8-byte alignment in structs?  If so, the layout is
correct.  If not (4-byte alignment), padding shifts may occur — though
analysis shows all uint64 fields happen to fall at 8-byte-aligned offsets
already, so the layout should be correct regardless.

These tests verify the actual compiled layout without booting QEMU.
"""

import os
import struct
import subprocess
import tempfile

import pytest

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
PROM_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CROSS_GCC = "/opt/cross/mips-elf/bin/mips-elf-gcc"
CROSS_OBJDUMP = "/opt/cross/mips-elf/bin/mips-elf-objdump"
# An XFS disk to check the superblock of; set PVPROM_TEST_DISK to enable.
TEST_DISK = os.environ.get("PVPROM_TEST_DISK", "")

have_toolchain = os.path.isfile(CROSS_GCC)
have_disk = bool(TEST_DISK) and os.path.isfile(TEST_DISK)

# ---------------------------------------------------------------------------
# Compiler flags (match toolchain.mk exactly)
# ---------------------------------------------------------------------------
CFLAGS = [
    "-march=mips3", "-mabi=32", "-EB", "-G", "0",
    "-mno-abicalls", "-fno-pic", "-msoft-float",
    "-ffreestanding", "-nostdlib", "-nostartfiles", "-O0",
    "-D_STANDALONE", "-D_KERNEL", "-DIP32", "-DR4000", "-D_MIPSEB",
    "-D_PAGESZ=16384", "-D_LANGUAGE_C",
    f"-I{PROM_DIR}/compat",
    f"-I{PROM_DIR}/include/ip32",
    f"-I{PROM_DIR}/include",
    f"-I{PROM_DIR}/include/sys",
    f"-include", f"{PROM_DIR}/compat/irix_compat.h",
]

# ---------------------------------------------------------------------------
# C source that stores offsetof() results in .data (readable via objdump)
# ---------------------------------------------------------------------------
# Fields listed in struct declaration order (xfs_sb.h)
FIELD_NAMES = [
    "sb_magicnum",   "sb_blocksize",  "sb_dblocks",   "sb_rblocks",
    "sb_rextents",   "sb_uuid",       "sb_logstart",   "sb_rootino",
    "sb_rbmino",     "sb_rsumino",    "sb_rextsize",   "sb_agblocks",
    "sb_agcount",    "sb_rbmblocks",  "sb_logblocks",  "sb_versionnum",
    "sb_sectsize",   "sb_inodesize",  "sb_inopblock",
    "sizeof_xfs_sb_t",
    "XFS_BIG_FILESYSTEMS", "XFS_BIG_FILES",
]

TEST_C_SRC = """\
#include <sys/types.h>
#include <sys/uuid.h>
#include <sys/fs/xfs_types.h>
#include <sys/fs/xfs_inum.h>
#include <sys/fs/xfs_sb.h>

/* Store offsetof results in .data so mips-elf-objdump -j .data -s can read them. */
int xfs_layout_results[] = {
    (int)__builtin_offsetof(xfs_sb_t, sb_magicnum),
    (int)__builtin_offsetof(xfs_sb_t, sb_blocksize),
    (int)__builtin_offsetof(xfs_sb_t, sb_dblocks),
    (int)__builtin_offsetof(xfs_sb_t, sb_rblocks),
    (int)__builtin_offsetof(xfs_sb_t, sb_rextents),
    (int)__builtin_offsetof(xfs_sb_t, sb_uuid),
    (int)__builtin_offsetof(xfs_sb_t, sb_logstart),
    (int)__builtin_offsetof(xfs_sb_t, sb_rootino),
    (int)__builtin_offsetof(xfs_sb_t, sb_rbmino),
    (int)__builtin_offsetof(xfs_sb_t, sb_rsumino),
    (int)__builtin_offsetof(xfs_sb_t, sb_rextsize),
    (int)__builtin_offsetof(xfs_sb_t, sb_agblocks),
    (int)__builtin_offsetof(xfs_sb_t, sb_agcount),
    (int)__builtin_offsetof(xfs_sb_t, sb_rbmblocks),
    (int)__builtin_offsetof(xfs_sb_t, sb_logblocks),
    (int)__builtin_offsetof(xfs_sb_t, sb_versionnum),
    (int)__builtin_offsetof(xfs_sb_t, sb_sectsize),
    (int)__builtin_offsetof(xfs_sb_t, sb_inodesize),
    (int)__builtin_offsetof(xfs_sb_t, sb_inopblock),
    (int)sizeof(xfs_sb_t),
    (int)XFS_BIG_FILESYSTEMS,
    (int)XFS_BIG_FILES,
};
"""


def _compile_and_read_offsets():
    """
    Compile TEST_C_SRC with the cross-compiler and read the .data section.
    Returns a dict {field_name: int_value} for each entry in FIELD_NAMES.
    """
    with tempfile.TemporaryDirectory() as tmpdir:
        src = os.path.join(tmpdir, "test_xfs_layout.c")
        obj = os.path.join(tmpdir, "test_xfs_layout.o")

        with open(src, "w") as f:
            f.write(TEST_C_SRC)

        # Compile to object file
        result = subprocess.run(
            [CROSS_GCC] + CFLAGS + ["-c", "-o", obj, src],
            capture_output=True, text=True, cwd=PROM_DIR,
        )
        if result.returncode != 0:
            raise RuntimeError(f"Compile failed:\n{result.stderr}")

        # Dump .data section
        result = subprocess.run(
            [CROSS_OBJDUMP, "-j", ".data", "-s", obj],
            capture_output=True, text=True,
        )
        if result.returncode != 0:
            raise RuntimeError(f"objdump failed:\n{result.stderr}")

        values = _parse_data_section(result.stdout)

    if len(values) < len(FIELD_NAMES):
        raise RuntimeError(
            f"Expected {len(FIELD_NAMES)} values in .data, got {len(values)}.\n"
            f"objdump output:\n{result.stdout}"
        )

    return dict(zip(FIELD_NAMES, values))


def _parse_data_section(objdump_out):
    """
    Parse big-endian int32 values from `mips-elf-objdump -j .data -s` output.

    Output format (each line):
      ADDR  HHHHHHHH HHHHHHHH HHHHHHHH HHHHHHHH  ................
    where each HHHHHHHH is 4 big-endian bytes (8 hex chars).
    """
    values = []
    in_contents = False
    for line in objdump_out.splitlines():
        if "Contents of section" in line:
            in_contents = True
            continue
        if not in_contents or not line.strip():
            continue
        parts = line.split()
        if not parts:
            continue
        # Verify first token is a hex address
        try:
            int(parts[0], 16)
        except ValueError:
            continue
        # Remaining tokens before the ASCII dump are 8-char hex groups
        for grp in parts[1:]:
            if len(grp) == 8:
                try:
                    word = struct.unpack(">I", bytes.fromhex(grp))[0]
                    values.append(word)
                except ValueError:
                    pass
            # The ASCII representation at end is not 8 chars — stop
    return values


# Cache the compiled offsets so we don't recompile per-test
_cached_offsets = None


def get_offsets():
    global _cached_offsets
    if _cached_offsets is None:
        _cached_offsets = _compile_and_read_offsets()
    return _cached_offsets


# ---------------------------------------------------------------------------
# Disk reading helpers (volume header + raw XFS superblock bytes)
# ---------------------------------------------------------------------------

# SGI volume header layout (all big-endian, fits in 512 bytes):
#   int    vh_magic          offset   0  (4 bytes)
#   short  vh_rootpt         offset   4  (2 bytes)
#   short  vh_swappt         offset   6  (2 bytes)
#   char   vh_bootfile[16]   offset   8  (16 bytes)
#   struct device_parameters vh_dp    offset 24  (48 bytes)
#   struct volume_directory  vh_vd[15] offset 72  (15*16=240 bytes)
#   struct partition_table   vh_pt[16] offset 312 (16*12=192 bytes)
#   int    vh_csum           offset 504
#   int    vh_fill           offset 508
VHMAGIC = 0x0be5a941
VH_PT_OFFSET = 312   # byte offset of partition table in volume header
VH_PT_SIZE = 12      # bytes per partition_table entry (3 × int32)

XFS_SB_MAGIC = 0x58465342   # 'XFSB'
XFS_SB_VERSION_OKSASHBITS = 0x3FFF  # valid mask for SASH version check


def _read_disk_sectors(disk, first_sector, count=1):
    """Return `count` raw 512-byte sectors from `disk` (qcow2 or raw)."""
    with tempfile.NamedTemporaryFile(suffix=".bin", delete=False) as f:
        tmpfile = f.name
    try:
        subprocess.run(
            [
                "qemu-img", "dd",
                f"if={disk}",
                f"of={tmpfile}",
                "bs=512",
                f"count={count}",
                f"skip={first_sector}",
            ],
            check=True, capture_output=True,
        )
        with open(tmpfile, "rb") as f:
            return f.read()
    finally:
        try:
            os.unlink(tmpfile)
        except OSError:
            pass


def _parse_volume_header(sector0):
    """Return dict of partition info from the SGI volume header."""
    magic = struct.unpack_from(">I", sector0, 0)[0]
    assert magic == VHMAGIC, f"VH magic mismatch: 0x{magic:08x} (expected 0x{VHMAGIC:08x})"

    partitions = []
    for i in range(16):
        offset = VH_PT_OFFSET + i * VH_PT_SIZE
        nblks, firstlbn, pt_type = struct.unpack_from(">iii", sector0, offset)
        partitions.append({"nblks": nblks, "firstlbn": firstlbn, "type": pt_type})
    return partitions


def _read_xfs_superblock(disk):
    """
    Locate the first XFS partition on `disk` and return the raw
    512-byte superblock sector.  Also returns the partition start LBN.
    """
    PTYPE_XFS = 10
    sector0 = _read_disk_sectors(disk, 0)
    partitions = _parse_volume_header(sector0)

    for i, pt in enumerate(partitions):
        if pt["type"] == PTYPE_XFS and pt["nblks"] > 0:
            sb_data = _read_disk_sectors(disk, pt["firstlbn"])
            return sb_data, pt["firstlbn"], i

    raise RuntimeError("No XFS partition found in disk volume header")


# ===========================================================================
# STRUCT LAYOUT TESTS
# ===========================================================================

@pytest.mark.skipif(not have_toolchain, reason="cross-compiler not available")
class TestXfsSbLayout:
    """Verify that the cross-compiled xfs_sb_t struct matches XFS on-disk format."""

    # Expected on-disk byte offsets (XFS specification, ABI-independent)
    EXPECTED = {
        "sb_magicnum":   0,
        "sb_blocksize":  4,
        "sb_dblocks":    8,    # xfs_drfsbno_t = __uint64_t (disk-based, always 64-bit)
        "sb_rblocks":    16,   # xfs_drfsbno_t = __uint64_t
        "sb_rextents":   24,   # xfs_drtbno_t  = __uint64_t
        "sb_uuid":       32,   # uuid_t = struct{char[16]}
        "sb_logstart":   48,   # xfs_dfsbno_t  = __uint64_t
        "sb_rootino":    56,   # xfs_ino_t     = __uint64_t (unconditional)
        "sb_rbmino":     64,   # xfs_ino_t     = __uint64_t
        "sb_rsumino":    72,   # xfs_ino_t     = __uint64_t
        "sb_rextsize":   80,   # xfs_agblock_t = __uint32_t
        "sb_agblocks":   84,
        "sb_agcount":    88,
        "sb_rbmblocks":  92,
        "sb_logblocks":  96,
        "sb_versionnum": 100,  # __uint16_t — THE CRITICAL FIELD
        "sb_sectsize":   102,
        "sb_inodesize":  104,
        "sb_inopblock":  106,
    }

    def test_versionnum_offset(self):
        """sb_versionnum MUST be at byte 100 for XFS recognition to work."""
        offsets = get_offsets()
        assert offsets["sb_versionnum"] == 100, (
            f"sb_versionnum is at offset {offsets['sb_versionnum']}, expected 100.\n"
            f"This causes _xfs_checkfs to read wrong bytes after bcopy().\n"
            f"Full layout: {offsets}"
        )

    def test_magicnum_offset(self):
        offsets = get_offsets()
        assert offsets["sb_magicnum"] == 0

    def test_uint64_fields_at_expected_offsets(self):
        """Disk-based uint64 fields must be at 8-byte-aligned positions."""
        offsets = get_offsets()
        for field in ("sb_dblocks", "sb_rblocks", "sb_rextents",
                      "sb_logstart", "sb_rootino", "sb_rbmino", "sb_rsumino"):
            expected = self.EXPECTED[field]
            actual = offsets[field]
            assert actual == expected, (
                f"{field}: got offset {actual}, expected {expected}"
            )

    def test_uint32_fields_at_expected_offsets(self):
        offsets = get_offsets()
        for field in ("sb_rextsize", "sb_agblocks", "sb_agcount",
                      "sb_rbmblocks", "sb_logblocks"):
            expected = self.EXPECTED[field]
            actual = offsets[field]
            assert actual == expected, (
                f"{field}: got offset {actual}, expected {expected}"
            )

    def test_uuid_offset(self):
        """uuid_t is a char[16] — no alignment padding, starts at 32."""
        offsets = get_offsets()
        assert offsets["sb_uuid"] == 32

    def test_all_expected_offsets(self):
        """All fields match expected on-disk layout in one assertion."""
        offsets = get_offsets()
        mismatches = {
            f: (offsets[f], exp)
            for f, exp in self.EXPECTED.items()
            if offsets[f] != exp
        }
        assert not mismatches, (
            "Struct layout mismatches (field: actual vs expected):\n" +
            "\n".join(f"  {f}: {a} != {e}" for f, (a, e) in mismatches.items())
        )

    def test_sizeof_xfs_sb_t(self):
        """sizeof(xfs_sb_t) should be 200 bytes (fits in one 512-byte sector)."""
        offsets = get_offsets()
        sz = offsets["sizeof_xfs_sb_t"]
        assert sz == 200, f"sizeof(xfs_sb_t) = {sz}, expected 200"

    def test_xfs_big_filesystems_is_zero(self):
        """With _MIPS_SIM=O32, XFS_BIG_FILESYSTEMS must be 0.
        This controls whether memory-based types (xfs_fsblock_t etc.) are 32 or 64-bit.
        Disk-based types (xfs_drfsbno_t, xfs_dfsbno_t, xfs_ino_t) are always 64-bit."""
        offsets = get_offsets()
        assert offsets["XFS_BIG_FILESYSTEMS"] == 0, (
            f"XFS_BIG_FILESYSTEMS={offsets['XFS_BIG_FILESYSTEMS']}, expected 0 for O32 ABI"
        )

    def test_xfs_big_files_is_zero(self):
        """With _MIPS_SIM=O32, XFS_BIG_FILES must be 0."""
        offsets = get_offsets()
        assert offsets["XFS_BIG_FILES"] == 0


# ===========================================================================
# DISK SUPERBLOCK TESTS
# ===========================================================================

@pytest.mark.skipif(not have_disk, reason="PVPROM_TEST_DISK not set or missing")
class TestDiskXfsSuperblock:
    """Verify the XFS superblock on the test disk is valid."""

    @pytest.fixture(scope="class")
    def superblock(self):
        sb_data, lbn, part_num = _read_xfs_superblock(TEST_DISK)
        return sb_data, lbn, part_num

    def test_xfs_partition_found(self, superblock):
        """An XFS partition exists in the volume header."""
        _, lbn, part_num = superblock
        assert lbn > 0, "XFS partition has zero start LBN"

    def test_magic_at_byte_0(self, superblock):
        """XFS magic 'XFSB' at bytes 0-3 of the superblock sector."""
        sb_data, _, _ = superblock
        magic = struct.unpack_from(">I", sb_data, 0)[0]
        assert magic == XFS_SB_MAGIC, (
            f"XFS magic mismatch: 0x{magic:08x}, expected 0x{XFS_SB_MAGIC:08x}"
        )

    def test_versionnum_at_byte_100(self, superblock):
        """sb_versionnum (uint16) at bytes 100-101 must be a valid XFS version."""
        sb_data, _, _ = superblock
        ver = struct.unpack_from(">H", sb_data, 100)[0]
        # Must be version 1-3 (old style) or version 4 with only known feature bits
        version_num = ver & 0x000F
        is_v1_to_v3 = 1 <= ver <= 3
        is_v4_ok = (version_num == 4) and not (ver & ~XFS_SB_VERSION_OKSASHBITS)
        assert is_v1_to_v3 or is_v4_ok, (
            f"sb_versionnum=0x{ver:04x} fails XFS_SB_GOOD_SASH_VERSION check.\n"
            f"  version_num (bits 0-3) = {version_num}\n"
            f"  unknown bits (ver & ~0x3fff) = 0x{ver & ~XFS_SB_VERSION_OKSASHBITS:04x}"
        )

    def test_blocksize_reasonable(self, superblock):
        """sb_blocksize should be a power of 2 between 512 and 65536."""
        sb_data, _, _ = superblock
        bs = struct.unpack_from(">I", sb_data, 4)[0]
        assert bs in (512, 1024, 2048, 4096, 8192, 16384, 32768, 65536), (
            f"Unexpected XFS block size: {bs}"
        )

    def test_raw_bytes_at_versionnum_offset(self, superblock):
        """Print the raw bytes at offset 100 for cross-reference with struct read."""
        sb_data, _, _ = superblock
        byte_100 = sb_data[100]
        byte_101 = sb_data[101]
        ver_raw = (byte_100 << 8) | byte_101
        # Also read what struct would give at offset 100 — should match
        ver_struct = struct.unpack_from(">H", sb_data, 100)[0]
        assert ver_raw == ver_struct  # sanity: these are the same thing
        # Report for debugging
        print(f"\n  disk bytes [100,101] = 0x{byte_100:02x}, 0x{byte_101:02x}"
              f"  → versionnum = 0x{ver_struct:04x}")


# ===========================================================================
# VERSION CHECK LOGIC TESTS (pure Python, no QEMU or toolchain needed)
# ===========================================================================

class TestVersionCheckLogic:
    """Verify XFS_SB_GOOD_SASH_VERSION logic for known version numbers."""

    def _good_sash_version(self, ver):
        """Python equivalent of XFS_SB_GOOD_SASH_VERSION macro."""
        version_num = ver & 0x000F
        XFS_SB_VERSION_1 = 1
        XFS_SB_VERSION_3 = 3
        XFS_SB_VERSION_4 = 4
        if XFS_SB_VERSION_1 <= ver <= XFS_SB_VERSION_3:
            return True
        if version_num == XFS_SB_VERSION_4 and not (ver & ~XFS_SB_VERSION_OKSASHBITS):
            return True
        return False

    def test_version_0x1094_passes(self):
        """0x1094 (version 4 + ALIGNBIT + ATTRBIT + EXTFLGBIT) should pass."""
        assert self._good_sash_version(0x1094), \
            "0x1094 should pass XFS_SB_GOOD_SASH_VERSION"

    def test_version_0x0100_fails(self):
        """0x0100 (the wrong value we're reading) should fail — version_num=0."""
        assert not self._good_sash_version(0x0100), \
            "0x0100 should fail XFS_SB_GOOD_SASH_VERSION (version_num=0, not 4)"

    def test_version_4_basic(self):
        """Pure version 4 with no feature bits passes."""
        assert self._good_sash_version(0x0004)

    def test_version_1_passes(self):
        assert self._good_sash_version(0x0001)

    def test_version_3_passes(self):
        assert self._good_sash_version(0x0003)

    def test_version_5_fails(self):
        """Version 5 is not recognized by the SASH check."""
        assert not self._good_sash_version(0x0005)

    def test_unknown_feature_bit_fails(self):
        """Version 4 with bit 14 set (not in OKSASHBITS mask) should fail."""
        assert not self._good_sash_version(0x4004)  # bit 14 set

    def test_oksashbits_mask(self):
        """XFS_SB_VERSION_OKSASHBITS = 0x3fff covers all known valid bits."""
        # NUMBITS(0x000f) | REALFBITS(0x0ff0) | OKSASHFBITS(0x3000)
        assert XFS_SB_VERSION_OKSASHBITS == 0x3FFF
