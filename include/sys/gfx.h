/*
 * sys/gfx.h -- Minimal stub for standalone PROM build
 */
#ifndef __SYS_GFX_H__
#define __SYS_GFX_H__

/* Graphics board info structure - minimal for PROM use */
struct gfx_info {
    int xpmax;      /* max X pixels */
    int ypmax;      /* max Y pixels */
};

#endif /* __SYS_GFX_H__ */
