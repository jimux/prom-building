/*
 * ctype.h -- Standalone character classification for PROM
 */
#ifndef __CTYPE_H__
#define __CTYPE_H__

/* Character class bit flags */
#define _U      0x01    /* upper case */
#define _L      0x02    /* lower case */
#define _N      0x04    /* digit */
#define _S      0x08    /* whitespace */
#define _P      0x10    /* punctuation */
#define _C      0x20    /* control */
#define _B      0x40    /* blank (space/tab) */
#define _X      0x80    /* hex digit */

extern unsigned char __ctype[];

#define isalpha(c)  (__ctype[(unsigned char)(c)+1] & (_U|_L))
#define isupper(c)  (__ctype[(unsigned char)(c)+1] & _U)
#define islower(c)  (__ctype[(unsigned char)(c)+1] & _L)
#define isdigit(c)  (__ctype[(unsigned char)(c)+1] & _N)
#define isxdigit(c) (__ctype[(unsigned char)(c)+1] & _X)
#define isalnum(c)  (__ctype[(unsigned char)(c)+1] & (_U|_L|_N))
#define isspace(c)  (__ctype[(unsigned char)(c)+1] & _S)
#define ispunct(c)  (__ctype[(unsigned char)(c)+1] & _P)
#define isprint(c)  (__ctype[(unsigned char)(c)+1] & (_P|_U|_L|_N|_B))
#define isgraph(c)  (__ctype[(unsigned char)(c)+1] & (_P|_U|_L|_N))
#define iscntrl(c)  (__ctype[(unsigned char)(c)+1] & _C)
#define isascii(c)  ((unsigned)(c) <= 0177)
#define toascii(c)  ((c) & 0177)

/* Low-level case conversion (no checking) */
#define _toupper(c) ((c) - 'a' + 'A')
#define _tolower(c) ((c) - 'A' + 'a')

/* toupper/tolower with checking */
#define toupper(c)  (islower(c) ? _toupper(c) : (c))
#define tolower(c)  (isupper(c) ? _tolower(c) : (c))

#endif /* __CTYPE_H__ */
