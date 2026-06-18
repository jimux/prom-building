/*
 * string.h -- Standalone string functions stub
 * In the PROM, string functions are provided by libsc.
 */
#ifndef __STRING_H__
#define __STRING_H__

#include <sys/types.h>

extern void *memcpy(void *, const void *, size_t);
extern void *memset(void *, int, size_t);
extern void *memmove(void *, const void *, size_t);
extern int   memcmp(const void *, const void *, size_t);
extern void  bcopy(const void *, void *, size_t);
extern void  bzero(void *, size_t);
extern int   bcmp(const void *, const void *, size_t);
extern char *strcpy(char *, const char *);
extern char *strncpy(char *, const char *, size_t);
extern char *strcat(char *, const char *);
extern int   strcmp(const char *, const char *);
extern int   strncmp(const char *, const char *, size_t);
extern size_t strlen(const char *);
extern char *strchr(const char *, int);
extern char *strrchr(const char *, int);
extern char *strstr(const char *, const char *);
extern char *index(const char *, int);
extern char *rindex(const char *, int);

#endif /* __STRING_H__ */
