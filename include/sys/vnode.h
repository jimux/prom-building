/* sys/vnode.h -- minimal stub for standalone PROM build (XFS reader) */
#ifndef __SYS_VNODE_H__
#define __SYS_VNODE_H__

#include <sys/types.h>
#include <sys/uio.h>

/* Vnode lock type */
typedef enum vrwlock {
    VRWLOCK_NONE,
    VRWLOCK_READ,
    VRWLOCK_WRITE,
    VRWLOCK_WRITE_DIRECT,
    VRWLOCK_TRY_READ,
    VRWLOCK_TRY_WRITE
} vrwlock_t;

/* Behavior descriptor - used by XFS inode as a header */
typedef struct bhv_desc {
    void           *bd_pdata;
    void           *bd_vobj;
    void           *bd_ops;
    struct bhv_desc *bd_next;
} bhv_desc_t;

/* Minimal vnode for standalone XFS */
struct vnode {
    int         v_type;
    bhv_desc_t  v_bh;
};
typedef struct vnode vnode_t;

/* Vnode type codes */
typedef enum vtype {
    VNON, VREG, VDIR, VBLK, VCHR, VLNK, VFIFO, VBAD, VSOCK, VXNAM
} vtype_t;

/* flid structure (file lock ID) */
struct flid { int fl_pid; };
typedef struct flid flid_t;

/* Vnode locking stubs - not used in standalone */
#define VN_LOCK(vp)
#define VN_UNLOCK(vp)
#define VN_HOLD(vp)
#define VN_RELE(vp)

/* Behavior list macros */
#define BHV_HEAD_FIRST(bh)  ((bh)->bh_first)
#define BHV_TO_VNODE(bdp)   ((vnode_t *)((bdp)->bd_vobj))

/* vnodeops stub */
struct vnodeops { int dummy; };

/* vn_bhv_head - simple version for standalone */
typedef struct vn_bhv_head {
    bhv_desc_t *bh_first;
} vn_bhv_head_t;

#endif /* __SYS_VNODE_H__ */
