/*
 * regdef.h -- GCC-compatible MIPS register name aliases
 *
 * Wraps the real IRIX regdef.h after ensuring sgidefs.h is resolved
 * to our compat version (needed for _MIPS_SIM checks).
 */
#ifndef __PVPROM_COMPAT_REGDEF_H__
#define __PVPROM_COMPAT_REGDEF_H__

#include "sgidefs.h"
#include <sys/regdef.h>

#endif /* __PVPROM_COMPAT_REGDEF_H__ */
