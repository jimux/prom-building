/*
 * finit.c -- Paravirtual firmware initialization (minimal, ARCS-only)
 *
 * Stripped of all CRIME/MACE/DS17287/MTE/tile/graphics hardware interactions.
 * Keeps: firmware entry, ARCS init, SPB setup, fw_dispatcher, halt/restart/reboot.
 */

#include <sys/cpu.h>
#include <sys/sbd.h>
#include <sys/types.h>
#include <arcs/restart.h>
#include <arcs/pvector.h>
#include <arcs/spb.h>
#include <arcs/errno.h>
#include <fwcallback.h>
#include <libsc.h>
#include <stringlist.h>

extern void config_cache(void);
extern void flush_cache(void);
extern void _hook_exceptions(void);
extern void init_env(void);
extern void _init_saio(void);
extern void SetSR(unsigned long);
extern unsigned long GetSR(void);
extern void _main(void);
extern void startup(void);
extern void cpu_hardreset(void);
extern void cpu_softreset(void);
extern void cpu_powerdown(void);

extern struct string_list environ_str;
void finit2(int, int);
void finit3(int, int);
void fw_dispatcher(int);
void FixupFirmwareVector(void);

int _prom = 0x0;
int _rtcinitted = 0x0;

/*
 * firmware -- called from csu.s after BSS is zeroed and stack is set up.
 */
void
firmware(int functionCode, int resetCount)
{
    config_cache();
    flush_cache();
    _hook_exceptions();
    SetSR(GetSR() & ~SR_BEV);
    init_env();
    finit2(functionCode, resetCount);
    finit3(functionCode, resetCount);
    fw_dispatcher(functionCode);
    while (1);
}

/*
 * finit2 -- bring up console and ARCS services
 */
void
finit2(int functionCode, int resetCount)
{
    (void)functionCode;
    (void)resetCount;
    _init_saio();
    initConsole();
}

/*
 * finit3 -- fix up SPB firmware vector
 */
void
finit3(int functionCode, int resetCount)
{
    (void)functionCode;
    (void)resetCount;
    FixupFirmwareVector();
}

/*
 * FixupFirmwareVector -- point SPB callbacks at our PROM implementations
 */
void
FixupFirmwareVector(void)
{
    FirmwareVector *SPB_TV = SPB->TransferVector;
    SPB_TV->EnterInteractiveMode = FWCB_EnterInteractiveMode;
    SPB_TV->Halt                 = FWCB_Halt;
    SPB_TV->PowerDown            = FWCB_PowerDown;
    SPB_TV->Restart              = FWCB_Restart;
    SPB_TV->Reboot               = FWCB_Reboot;
}

/* SPB callback wrappers */
void EnterInteractiveMode(void) {
    FirmwareVector *SPB_TV = SPB->TransferVector;
    (*SPB_TV->EnterInteractiveMode)();
}

void Halt(void) {
    FirmwareVector *SPB_TV = SPB->TransferVector;
    (*SPB_TV->Halt)();
}

void PowerDown(void) {
    FirmwareVector *SPB_TV = SPB->TransferVector;
    (*SPB_TV->PowerDown)();
}

void Restart(void) {
    FirmwareVector *SPB_TV = SPB->TransferVector;
    (*SPB_TV->Restart)();
}

void Reboot(void) {
    FirmwareVector *SPB_TV = SPB->TransferVector;
    (*SPB_TV->Reboot)();
}

/* halt -- serial only */
void
halt(void)
{
    printf("\n\nOkay to power off the system now.\n\n"
           "Press RESET button to restart.");
    getchar();
    putchar('\n');
    cpu_hardreset();
}

void
powerdown(void)
{
    cpu_powerdown();
}

void
restart(void)
{
    startup();
    _main();
}

void
reboot(void)
{
    if (ESUCCESS != autoboot(0, 0, 0)) {
        p_curson();
        p_printf("Unable to boot; press any key to continue: ");
        getchar();
        putchar('\n');
    }
    EnterInteractiveMode();
}

/*
 * IP32firmware_init -- arcs init command (restart from PROM entry)
 */
int
IP32firmware_init(void)
{
    (*(void(*)(int,int))0xbfc00000)(FW_INIT, 0);
    return 0; /* not reached */
}

/*
 * fw_dispatcher -- dispatch based on firmware function code
 */
void
fw_dispatcher(int dispatchCode)
{
    switch (dispatchCode) {
    case FW_HARD_RESET:
    case FW_SOFT_RESET:
    case FW_INIT:
        startup();
        /* fall through */
    case FW_EIM:
        _main();
        break;
    case FW_HALT:
        halt();
        break;
    case FW_POWERDOWN:
        powerdown();
        break;
    case FW_RESTART:
        restart();
        break;
    case FW_REBOOT:
        reboot();
        break;
    default:
        return;
    }
    while (1);
}
