/*
 * debugcard.h -- Stub for standalone PROM build
 * The debug card is not present in our IP54 build.
 */
#ifndef __DEBUGCARD_H__
#define __DEBUGCARD_H__

#define DEBUGCARD_PRESENT 0

/* Debug card UART base address (ISA slot on IP32 debug card) */
#define UARTaddr	0xbfd00000

#endif /* __DEBUGCARD_H__ */
