/*
 * sys/signal.h -- Minimal stub for standalone PROM build
 * Only the constants used in assembly code are needed.
 */
#ifndef __SYS_SIGNAL_H__
#define __SYS_SIGNAL_H__

#define SIGINT      2
#define SIGALRM     14

/* Signal handler values */
#define SIG_DFL     0
#define SIG_IGN     1

/* Break codes used by assembly */
#define BRK_KERNELBP    1       /* kernel breakpoint (used by prom) */

#endif /* __SYS_SIGNAL_H__ */
