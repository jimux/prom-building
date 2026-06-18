/*
 * main.c -- main line prom code (IP54 minimal)
 *
 * Stripped of GUI mode, MACE LEDs, IP32SIM ifdefs.
 */

#include <arcs/restart.h>
#include <arcs/signal.h>
#include <sys/cpu.h>
#include <parser.h>
#include <setjmp.h>
#include <menu.h>
#include <libsc.h>

#define PROMPT "> "

extern menu_t prom_menu;
extern jmp_buf restart_buf;

static void main_intr(void);
static int version(int, char **, char **, struct cmd_table *);

/* commands - all take (int argc, char **argv, char **argp, struct cmd_table *) */
extern int reboot_cmd(), single(), put(), get(), auto_cmd(), checksum();
extern int date_cmd(), dump(), gioinfo();
extern int play_cmd(), poweroff_cmd();
extern int readc0_cmd(), writec0_cmd();
extern int fill(), passwd_cmd(), resetpw_cmd();
extern int resetenv();
extern int exit_cmd();
extern char *getversion(void);
static int IP32firmware_init(int, char **, char **, struct cmd_table *);

/*
 * cmd_table -- interface between parser and command execution routines
 */
static struct cmd_table cmd_table[] = {
	{ "auto",	auto_cmd,	"autoboot:\tauto" },
	{ "boot",	boot,		"boot:\t\tboot [-f FILE] [-n] [ARGS]" },
	{ ".checksum",	checksum,	"checksum:\tchecksum RANGE" },
	{ "date",	date_cmd,	"date:\t\tdate [mmddhhmm[ccyy|yy][.ss]]"},
	{ ".dump",	dump,		"dump:\t\tdump [-(b|h|w)] [-(o|d|u|x|c|B)] RANGE" },
	{ "exit",	exit_cmd,	"exit:\t\texit" },
	{ ".fill", CT_ROUTINE fill,	"fill:\t\tfill [-(b|h|w)] [-v VAL] RANGE" },
	{ "get",	get,		"get:\t\tg [-(b|h|w|d)] ADDRESS" },
	{ "put",	put,		"put:\t\tp [-(b|h|w|d)] ADDRESS VALUE" },
	{ ".g",		get,		"get:\t\tg [-(b|h|w|d)] ADDRESS" },
	{ ".p",		put,		"put:\t\tp [-(b|h|w|d)] ADDRESS VALUE" },
	{ ".go",	go_cmd,		"go:\t\tgo [INITIAL_PC]" },
	{ "help",	help,		"help:\t\thelp or ? [COMMAND]" },
	{ ".?",		help,		"help:\t\t? [COMMAND]" },
	{ "init",   IP32firmware_init,  "initialize:\tinit" },
	{ "hinv",	hinv,		"inventory:\thinv [-v] [-t [-p]]" },
	{ "ls",		ls,		"list files:\tls DEVICE" },
	{ "passwd",	passwd_cmd,	"passwd:\t\tpasswd" },
	{ ".play",	play_cmd,	"play <tune #>" },
	{ "off",	poweroff_cmd,	"power off machine:\toff" },
	{ "printenv",	printenv_cmd,	"printenv:\tprintenv [ENV_VAR_LIST]" },
	{ ".reboot",	reboot_cmd,	"reboot:\t\treboot" },
	{ "resetenv", CT_ROUTINE resetenv,	"resetenv:\tresetenv" },
	{ "resetpw",	resetpw_cmd,	"resetpw:\tresetpw" },
	{ "setenv",	setenv_cmd,	"setenv:\t\tsetenv ENV_VAR STRING" },
	{ "single",	single,		"single user:\tsingle" },
	{ "unsetenv",	unsetenv_cmd,	"unsetenv:\tunsetenv ENV_VAR" },
	{ "version",	version,	"version:\tversion" },
	{ 0,		0,		"" }
};

/*
 * _main -- called from fw_dispatcher after ARCS init
 */
_main()
{
	char *diskless;
	extern int Verbose;

	(void)rbsetbs(BS_PREADY);
	(void)init_prom_menu();
	Signal(SIGINT, main_intr);

	for (;;) {
		setjmp(restart_buf);
		close_noncons();

		if (getenv("VERBOSE") == 0)
			Verbose = 0;

		/* update menu */
		diskless = getenv("diskless");
		prom_menu.item[0].flags &= ~M_INVALID;
		prom_menu.item[1].flags &= ~M_INVALID;
		prom_menu.item[2].flags &= ~M_INVALID;
		prom_menu.item[3].flags &= ~M_INVALID;
		prom_menu.item[4].flags &= ~M_INVALID;
		prom_menu.item[5].flags &= ~M_INVALID;

		if (diskless && (*diskless == '1')) {
			prom_menu.item[1].flags |= M_INVALID;
			prom_menu.item[3].flags |= M_INVALID;
		}

		/* Menu parser returns for manual mode */
		menu_parser(&prom_menu);

		/* re-Mark point */
		setjmp(restart_buf);
		close_noncons();
		_scandevs();

		if (getenv("VERBOSE") == 0)
			Verbose = 1;

		/* Manual mode */
		command_parser(cmd_table, PROMPT, 1, 0);
	}
}

static void
main_intr(void)
{
	printf("\n");
	Signal(SIGALRM, SIGIgnore);
	longjmp(restart_buf, 1);
}

static int
version(int argc, char **argv, char **argp, struct cmd_table *xxx)
{
	printf("\n\nPROM Monitor (BE)\n%s\n", getversion());
	return 0;
}

/*
 * IP32firmware_init -- implement arcs init command
 */
static int
IP32firmware_init(int argc, char **argv, char **argp, struct cmd_table *ct)
{
	(void)argc; (void)argv; (void)argp; (void)ct;
	(*(void(*)(int,int))0xbfc00000)(FW_INIT, 0);
	return 0;
}
