/*
 * sys/ioctl.h -- Minimal stub for standalone PROM build
 */
#ifndef __SYS_IOCTL_H__
#define __SYS_IOCTL_H__

#define _IOC(x,y,z)     (((x)<<8)|(y))
#define _IO(x,y)        _IOC(x,y,0)
#define _IOR(x,y,t)     _IOC(x,y,sizeof(t))
#define _IOW(x,y,t)     _IOC(x,y,sizeof(t))
#define _IOWR(x,y,t)    _IOC(x,y,sizeof(t))

#endif /* __SYS_IOCTL_H__ */
