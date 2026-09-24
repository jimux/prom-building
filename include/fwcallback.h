/*
 * fwcallback.h -- Firmware callback declarations
 *
 * For the single-stage paravirtual PROM, these are implemented in pv_stubs.c.
 */
#ifndef __FWCALLBACK_H__
#define __FWCALLBACK_H__

extern void FWCB_Halt(void);
extern void FWCB_Restart(void);
extern void FWCB_Reboot(void);
extern void FWCB_PowerDown(void);
extern void FWCB_EnterInteractiveMode(void);

#endif /* __FWCALLBACK_H__ */
