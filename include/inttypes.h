/*
 * inttypes.h -- Standalone stub
 * Just pull in stdint.h for the integer types.
 */
#ifndef __INTTYPES_H__
#define __INTTYPES_H__

#include <stdint.h>

/* printf format macros - not needed for PROM but satisfy compilation */
#define PRId32 "d"
#define PRIu32 "u"
#define PRIx32 "x"
#define PRId64 "lld"
#define PRIu64 "llu"
#define PRIx64 "llx"

#endif /* __INTTYPES_H__ */
