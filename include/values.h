/* values.h -- numeric limits for standalone PROM build */
#ifndef _VALUES_H
#define _VALUES_H

#define MAXLONG     0x7fffffff
#define MINLONG     0x80000000
#define MAXULONG    0xffffffff
#define MAXSHRT     32767
#define MINSHRT     (-32768)
#define MAXINT      0x7fffffff
#define MININT      0x80000000
#define MAXUINT     0xffffffff
#define BITSPERBYTE 8
#define BITS(type)  (BITSPERBYTE * sizeof(type))
#define HIBITS      0x8000
#define HIBITL      0x80000000
#define MAXDOUBLE   1.79769313486231570e+308
#define MAXFLOAT    3.40282346638528860e+38F
#define MINFLOAT    1.17549435082228750e-38F
#define MINDOUBLE   2.22507385850720140e-308

#endif /* _VALUES_H */
#define WORD_BIT    32
