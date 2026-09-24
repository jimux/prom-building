/*
 * env.c -- RAM-only environment variables for paravirtual PROM
 *
 * Replaces the flash-backed env.c from IP32. Changes are in-memory only
 * (lost on reset), which is fine for QEMU.
 */

#include <sys/cpu.h>
#include <arcs/errno.h>
#include <sys/types.h>
#include <stringlist.h>
#include <saioctl.h>
#include <arcs/io.h>
#include <libsc.h>

/* Forward declarations */
extern struct string_list environ_str;
extern char **environ;
extern char *netaddr_default;
extern int Debug, Verbose, _udpcksum;

struct cmd_table;

/* Default environment table */
static struct {
    char *name;
    char *value;
} default_env[] = {
    { "console",         "d" },
    { "AutoLoad",        "Yes" },
    { "OSLoadPartition", "dksc(0,1,0)" },
    { "SystemPartition", "dksc(0,1,8)" },
    { "OSLoader",        "sash" },
    { "OSLoadFilename",  "/unix.new" },
    { "bootfile",        "dksc(0,1,0)/unix.new" },
    { "eaddr",           "08:00:69:aa:bb:cc" },
    { "cpufreq",         "200" },
    { "dbaud",           "9600" },
    { "rbaud",           "9600" },
    { "pagecolor",       "67" },
    { "nogfxkbd",        "1" },
    { "diskless",        "0" },
    { "TimeZone",        "PST8PDT" },
    { "volume",          "80" },
    { 0, 0 }
};

/* Special variables that mirror into C globals */
#define SENV_READONLY 1
#define VARIABLE 2

static struct special {
    char *name;
    int *value;
    int flags;
} special_tab[] = {
    { "DEBUG",     &Debug,     VARIABLE },
    { "VERBOSE",   &Verbose,   VARIABLE },
    { "_udpcksum", &_udpcksum, VARIABLE },
    { "gfx",      0,           SENV_READONLY },
    { "cpufreq",  0,           SENV_READONLY },
    { "eaddr",    0,           SENV_READONLY },
    { 0, 0, 0 }
};

/*
 * _setenv -- set or unset an environment variable
 */
int
_setenv(char *name, char *value, int override)
{
    int unset = (value == 0) || (*value == '\0');
    struct special *sp;

    for (sp = special_tab; sp->name; sp++) {
        if (strcasecmp(name, sp->name) == 0) {
            if (override != 1 && (sp->flags & SENV_READONLY))
                return EACCES;
            if (sp->flags & VARIABLE) {
                if (unset)
                    *sp->value = 0;
                else
                    atob(value, sp->value);
            }
            break;
        }
    }

    if (unset)
        delete_str(name, &environ_str);
    else
        replace_str(name, value, &environ_str);

    return ESUCCESS;
}

/*
 * init_env -- populate environment from defaults
 */
void
init_env(void)
{
    int i;

    init_str(&environ_str);

    for (i = 0; default_env[i].name; i++) {
        if (default_env[i].value && *default_env[i].value)
            syssetenv(default_env[i].name, default_env[i].value);
    }

    environ = environ_str.strptrs;

    /* Derive ConsoleIn/Out from console */
    init_consenv(0);
}

/*
 * resetenv -- reset environment to defaults
 */
int
resetenv(void)
{
    int i;

    init_str(&environ_str);

    for (i = 0; default_env[i].name; i++) {
        if (default_env[i].value && *default_env[i].value)
            syssetenv(default_env[i].name, default_env[i].value);
    }

    environ = environ_str.strptrs;
    init_consenv(0);
    return 0;
}

/*
 * get_nvram_tab -- kernel callback to get environment table
 * Returns bytes NOT copied (so kernel can detect overflow).
 */
int
get_nvram_tab(char *addr, int size)
{
    (void)addr;
    (void)size;
    return 0;
}

/* ================================================================
 * Environment commands
 * ================================================================ */

static char *readonly_errmsg = "Environment variable \"%s\" is"
    " informative only and cannot be changed.\n";

static char *nvram_errmsg = "Error writing \"%s\" to the non-volatile RAM.\n"
    "Variable \"%s\" is not saved in the permanent environment.\n";

int
setenv_cmd(int argc, char **argv, char **bunk1, struct cmd_table *bunk2)
{
    int rval, override;
    char *var, *val;
    ULONG fd;

    if (argc == 4) {
        if (strcmp(argv[1], "-f") == 0) {
            override = 1;
            var = argv[2];
            val = argv[3];
        } else if (strcmp(argv[1], "-p") == 0) {
            override = 2;
            var = argv[2];
            val = argv[3];
        } else
            return 1;
    } else if (argc != 3)
        return 1;
    else {
        override = 0;
        var = argv[1];
        val = argv[2];
    }

    rval = _setenv(var, val, override);

    if (rval == EACCES) {
        printf(readonly_errmsg, var);
        return 0;
    } else if (rval != 0)
        printf(nvram_errmsg, var, var);

    if (!strcasecmp(var, "dbaud") &&
        (Open((CHAR *)"serial(0)", OpenReadWrite, &fd) == ESUCCESS)) {
        ioctl(fd, TIOCREOPEN, 0);
        Close(fd);
    }

    if (!strcasecmp(var, "rbaud") &&
        (Open((CHAR *)"serial(1)", OpenReadWrite, &fd) == ESUCCESS)) {
        ioctl(fd, TIOCREOPEN, 0);
        Close(fd);
    }

    return 0;
}

int
unsetenv_cmd(int argc, char **argv, char **bunk1, struct cmd_table *bunk2)
{
    int rval;

    if (argc != 2)
        return 1;

    if ((rval = setenv(argv[1], "")) != 0) {
        if (rval == EACCES)
            printf(readonly_errmsg, argv[1]);
        else
            printf(nvram_errmsg, argv[1], argv[1]);
    }

    return 0;
}

void
printenv(char *var)
{
    char *cp;

    if (cp = find_str(var, &environ_str))
        printf("%s\n", cp);
}

int
printenv_cmd(int argc, char **argv, char **bunk1, struct cmd_table *bunk2)
{
    int i;

    if (argc == 1) {
        for (i = 0; i < environ_str.strcnt; i++)
            printf("%s\n", environ_str.strptrs[i]);
    } else {
        while (--argc > 0)
            printenv(*++argv);
    }

    return 0;
}

/* htoe/etoh -- required by linker but never actually called */
char *
htoe(unsigned char *hex)
{
    (void)hex;
    return (char *)0;
}

unsigned char *
etoh(char *enet)
{
    (void)enet;
    return (unsigned char *)0;
}
