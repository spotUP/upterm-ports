/* script -- make a typescript of a terminal session (UP-Term).
 *
 *   script [-aeqf] [-c command] [file [command ...]]
 *
 * Starts a shell (or the command) on a pseudo-terminal, copies the terminal
 * to the screen and to file (default "typescript"), and ends when the shell
 * does. -a appends to the file, -q leaves out the messages, -f flushes the
 * file after each write, -e exits with the command's status, -c runs a
 * command through $SHELL -c; words after the file are a command too (BSD
 * form). The file starts with a "Script started" line and ends with a
 * "Script done" line that holds the date and the exit status.
 *
 * ixemul has no fork: the child is a vfork that only sets up its own kernel
 * state (setsid, the slave as controlling terminal and as fds 0-2) and execs,
 * as ptyrun does. */
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/select.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <termios.h>
#include <time.h>
#include <unistd.h>

#define VERSION "1.0"

static struct termios saved_tio;
static int have_tio;
static volatile sig_atomic_t winch;
static int master = -1;

static void
on_signal(int sig)
{
	if (sig == SIGWINCH)
		winch = 1;
}

static void
restore_tty(void)
{
	if (have_tio) {
		tcsetattr(0, TCSANOW, &saved_tio);
		have_tio = 0;
	}
}

static void
stamp(char *buf, size_t n)
{
	time_t now = time(NULL);

	strftime(buf, n, "%Y-%m-%d %H:%M:%S", localtime(&now));
}

static void
usage(FILE *f)
{
	fputs("Usage: script [-aeqf] [-c command] [file [command ...]]\n"
	      "  -a  append to the file        -q  no messages\n"
	      "  -f  flush after each write    -e  exit with the command's status\n"
	      "  -c  run command (through $SHELL -c)\n"
	      "  -V  print the version\n", f);
}

int
main(int argc, char **argv)
{
	int append = 0, quiet = 0, flush = 0, errexit = 0, c, status = 0, eof_seen = 0, eof_sent = 0;
	const char *file = "typescript", *cmd = NULL, *shell;
	char *shargv[4], **childargv;
	char *sname, when[64], buf[4096], *cmdline = NULL;
	struct sigaction sa;
	struct winsize ws;
	struct termios raw;
	FILE *log;
	pid_t pid;
	int have_ws;

	while ((c = getopt(argc, argv, "+aqfec:Vh")) != -1) {
		switch (c) {
		case 'a': append = 1; break;
		case 'q': quiet = 1; break;
		case 'f': flush = 1; break;
		case 'e': errexit = 1; break;
		case 'c': cmd = optarg; break;
		case 'V': printf("script %s (UP-Term)\n", VERSION); return 0;
		case 'h': usage(stdout); return 0;
		default: usage(stderr); return 1;
		}
	}
	if (optind < argc)
		file = argv[optind++];
	shell = getenv("SHELL");
	if (!shell || !*shell)
		shell = "/bin/sh";
	if (cmd) {
		shargv[0] = (char *)shell;
		shargv[1] = "-c";
		shargv[2] = (char *)cmd;
		shargv[3] = NULL;
		childargv = shargv;
		cmdline = (char *)cmd;
	} else if (optind < argc) {
		childargv = argv + optind;
		cmdline = argv[optind];
	} else {
		shargv[0] = (char *)shell;
		shargv[1] = "-i";
		shargv[2] = NULL;
		childargv = shargv;
	}

	if (!(log = fopen(file, append ? "a" : "w"))) {
		fprintf(stderr, "script: cannot open %s: %s\n", file, strerror(errno));
		return 1;
	}
	if ((master = posix_openpt(O_RDWR | O_NOCTTY)) < 0 || grantpt(master) || unlockpt(master) ||
	    !(sname = ptsname(master))) {
		fprintf(stderr, "script: no pseudo-terminal: %s\n", strerror(errno));
		return 1;
	}
	have_ws = isatty(0) && ioctl(0, TIOCGWINSZ, &ws) == 0;
	if (!have_ws) {
		memset(&ws, 0, sizeof ws);
		ws.ws_col = 80;
		ws.ws_row = 24;
	}
	ioctl(master, TIOCSWINSZ, &ws);

	stamp(when, sizeof when);
	fprintf(log, "Script started on %s", when);
	if (cmdline)
		fprintf(log, " [COMMAND=\"%s\"]", cmdline);
	fputc('\n', log);
	if (!quiet)
		printf("Script started, output log file is '%s'.\n", file);
	fflush(stdout);

	memset(&sa, 0, sizeof sa);
	sa.sa_handler = on_signal;
	sigaction(SIGWINCH, &sa, 0);

	if ((pid = vfork()) == 0) {
		int s;

		setsid();
		if ((s = open(sname, O_RDWR)) < 0)
			_exit(126);
		ioctl(s, TIOCSCTTY, 0);
		ioctl(s, TIOCSWINSZ, &ws);
		dup2(s, 0);
		dup2(s, 1);
		dup2(s, 2);
		if (s > 2)
			close(s);
		close(master);
		execvp(childargv[0], childargv);
		_exit(127);
	}
	if (pid < 0) {
		perror("script: vfork");
		return 1;
	}

	if (isatty(0) && tcgetattr(0, &saved_tio) == 0) {
		raw = saved_tio;
		cfmakeraw(&raw);
		raw.c_oflag = saved_tio.c_oflag;
		tcsetattr(0, TCSANOW, &raw);
		have_tio = 1;
	}

	for (;;) {
		fd_set rd;
		struct timeval idle = { 0, 300000 }, *tp = eof_seen && !eof_sent ? &idle : NULL;
		int n, maxfd = master;

		FD_ZERO(&rd);
		FD_SET(master, &rd);
		if (!eof_seen) {
			FD_SET(0, &rd);
			if (0 > maxfd)
				maxfd = 0;
		}
		n = select(maxfd + 1, &rd, 0, 0, tp);
		if (winch) {
			winch = 0;
			if (isatty(0) && ioctl(0, TIOCGWINSZ, &ws) == 0)
				ioctl(master, TIOCSWINSZ, &ws);
		}
		if (n < 0) {
			if (errno == EINTR)
				continue;
			break;
		}
		if (n == 0 && eof_seen && !eof_sent) {
			/* our input ended and the command is still running and quiet: it
			 * waits for input, so give it the terminal's EOF (^D). Not sent at
			 * once: a command that never reads (echo) would see the tty echo
			 * it as "^D" in the typescript. */
			char eof = 4;

			write(master, &eof, 1);
			eof_sent = 1;
			continue;
		}
		if (FD_ISSET(master, &rd)) {
			ssize_t r = read(master, buf, sizeof buf);

			if (r <= 0)
				break;
			write(1, buf, (size_t)r);
			fwrite(buf, 1, (size_t)r, log);
			if (flush)
				fflush(log);
		}
		if (!eof_seen && FD_ISSET(0, &rd)) {
			ssize_t r = read(0, buf, sizeof buf);

			if (r > 0)
				write(master, buf, (size_t)r);
			else if (r == 0 || errno != EINTR)
				eof_seen = 1;
		}
	}
	restore_tty();
	while (waitpid(pid, &status, 0) < 0 && errno == EINTR)
		;
	{
		int code = WIFEXITED(status) ? WEXITSTATUS(status) : 128 + WTERMSIG(status);

		stamp(when, sizeof when);
		fprintf(log, "\nScript done on %s [COMMAND_EXIT_CODE=\"%d\"]\n", when, code);
		fclose(log);
		if (!quiet)
			printf("Script done, output log file is '%s'.\n", file);
		return errexit ? code : 0;
	}
}
