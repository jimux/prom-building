/* limits.h -- standalone PROM build */
#ifndef _LIMITS_H
#define _LIMITS_H

#define CHAR_BIT    8
#define SCHAR_MIN   (-128)
#define SCHAR_MAX   127
#define UCHAR_MAX   255
#define SHRT_MIN    (-32768)
#define SHRT_MAX    32767
#define USHRT_MAX   65535
#define INT_MIN     (-2147483648)
#define INT_MAX     2147483647
#define UINT_MAX    4294967295U
#define LONG_MIN    (-2147483648L)
#define LONG_MAX    2147483647L
#define ULONG_MAX   4294967295UL
#define LLONG_MAX   9223372036854775807LL
#define LLONG_MIN   (-LLONG_MAX - 1LL)
#define ULLONG_MAX  18446744073709551615ULL

/* Word size */
#define WORD_BIT    32
#define LONG_BIT    32

/* Path/name limits */
#define MAXPATHLEN  1024
#define MAXNAMELEN  256
#define PATH_MAX    1024
#define NAME_MAX    255

#endif /* _LIMITS_H */
