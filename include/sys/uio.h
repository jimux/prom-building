/* sys/uio.h -- stub for standalone PROM build */
#ifndef __SYS_UIO_H__
#define __SYS_UIO_H__
#include <sys/types.h>
typedef struct iovec { void *iov_base; size_t iov_len; } iovec_t;
typedef struct uio { iovec_t *uio_iov; int uio_iovcnt; off_t uio_offset;
    int uio_segflg; int uio_fmode; ssize_t uio_resid; } uio_t;
#define UIO_SYSSPACE 0
#define UIO_USERSPACE 1
#endif
