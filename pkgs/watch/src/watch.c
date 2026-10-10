/* watch -- run a command over and over and show its output (UP-Term).
 *
 *   watch [-bdegptvx] [-n seconds] command [argument ...]
 *
 * The command runs through /bin/sh -c (the words joined by spaces) or, with
 * -x, is started directly. Its standard output and error come back through a
 * pipe, the screen is redrawn after each run. No fork: the command is
 * started with posix_spawn(p). Only ANSI sequences are written, no curses:
 * the terminal is vtcon's, or any xterm.
 *
 *   -n, --interval SEC    seconds between runs (default 2, least 0.1)
 *   -d, --differences     show what changed since the last run in reverse video
 *   -t, --no-title        no header
 *   -e, --errexit         stop when the command fails, after a key
 *   -g, --chgexit         stop when the output changes
 *   -b, --beep            beep when the command fails
 *   -c, --color           pass the command's colour sequences through
 *   -p, --precise         count the interval from the start of a run
 *   -x, --exec            run the command directly, not through the shell
 *   -v, --version, -h, --help
 *
 * Keys: q quits, a space runs the command again now.
 * Exit status: 0 after q or a signal, 1 on a usage or system error, 8 after
 * -e on a failing command, 0 after -g. */
#include <errno.h>
#include <getopt.h>
#include <signal.h>
#include <spawn.h>
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

extern char **environ;

static volatile sig_atomic_t quit, winch;
static struct termios saved_tio;
static int have_tio;
static int in_screen;

static int opt_diff, opt_notitle, opt_errexit, opt_chgexit, opt_beep, opt_color, opt_precise, opt_exec;
static double interval = 2.0;

struct buf {
	char *p;
	size_t len, cap;
};

static void
bputs(struct buf *b, const char *s, size_t n)
{
	if (b->len + n + 1 > b->cap) {
		b->cap = (b->len + n + 1) * 2;
		if (!(b->p = realloc(b->p, b->cap))) {
			perror("watch");
			exit(1);
		}
	}
	memcpy(b->p + b->len, s, n);
	b->len += n;
	b->p[b->len] = 0;
}

static void
on_signal(int sig)
{
	if (sig == SIGWINCH)
		winch = 1;
	else
		quit = 1;
}

static void
leave_screen(void)
{
	if (in_screen) {
		fputs("\033[0m\033[?25h\033[?1049l", stdout);
		fflush(stdout);
		in_screen = 0;
	}
	if (have_tio) {
		tcsetattr(0, TCSANOW, &saved_tio);
		have_tio = 0;
	}
}

static void
enter_screen(void)
{
	if (isatty(0) && tcgetattr(0, &saved_tio) == 0) {
		struct termios t = saved_tio;

		t.c_lflag &= ~(ICANON | ECHO);
		t.c_cc[VMIN] = 1;
		t.c_cc[VTIME] = 0;
		tcsetattr(0, TCSANOW, &t);
		have_tio = 1;
	}
	fputs("\033[?1049h\033[?25l\033[2J", stdout);
	in_screen = 1;
}

static void
screen_size(int *cols, int *rows)
{
	struct winsize ws;
	char *e;

	*cols = 80;
	*rows = 24;
	if (ioctl(1, TIOCGWINSZ, &ws) == 0 && ws.ws_col > 0 && ws.ws_row > 0) {
		*cols = ws.ws_col;
		*rows = ws.ws_row;
	} else {
		if ((e = getenv("COLUMNS")) && atoi(e) > 0)
			*cols = atoi(e);
		if ((e = getenv("LINES")) && atoi(e) > 0)
			*rows = atoi(e);
	}
}

/* Run the command; its output goes to out. Returns the wait status, or -1. */
static int
run(char **argv, struct buf *out)
{
	int fd[2], status;
	pid_t pid;
	posix_spawn_file_actions_t fa;
	char tmp[4096];
	ssize_t n;
	int rc;

	out->len = 0;
	if (out->p)
		out->p[0] = 0;
	if (pipe(fd) < 0)
		return -1;
	posix_spawn_file_actions_init(&fa);
	posix_spawn_file_actions_adddup2(&fa, fd[1], 1);
	posix_spawn_file_actions_adddup2(&fa, fd[1], 2);
	posix_spawn_file_actions_addclose(&fa, fd[0]);
	if (fd[1] > 2)
		posix_spawn_file_actions_addclose(&fa, fd[1]);
	rc = opt_exec ? posix_spawnp(&pid, argv[0], &fa, NULL, argv, environ)
		      : posix_spawn(&pid, "/bin/sh", &fa, NULL, argv, environ);
	posix_spawn_file_actions_destroy(&fa);
	close(fd[1]);
	if (rc != 0) {
		char msg[256];

		snprintf(msg, sizeof msg, "watch: cannot run %s: %s\n", argv[opt_exec ? 0 : 2], strerror(rc));
		bputs(out, msg, strlen(msg));
		close(fd[0]);
		return 127 << 8;
	}
	while ((n = read(fd[0], tmp, sizeof tmp)) != 0) {
		if (n < 0) {
			if (errno == EINTR && !quit)
				continue;
			break;
		}
		bputs(out, tmp, (size_t)n);
	}
	close(fd[0]);
	while (waitpid(pid, &status, 0) < 0 && errno == EINTR && !quit)
		;
	return status;
}

/* One line of output -> at most cols screen columns, with the differences
 * against the same line of the previous run in reverse video. */
static void
draw_line(const char *s, size_t n, const char *old, size_t oldn, int cols, struct buf *screen)
{
	int col = 0, rev = 0;
	size_t i;

	for (i = 0; i < n && col < cols; i++) {
		unsigned char c = (unsigned char)s[i];
		int changed;

		if (c == '\033') {
			size_t j = i + 1;

			if (opt_color && j < n && s[j] == '[') {
				for (j++; j < n && !((unsigned char)s[j] >= 0x40 && (unsigned char)s[j] <= 0x7e); j++)
					;
				if (j < n && s[j] == 'm')
					bputs(screen, s + i, j - i + 1);
			}
			i = j < n ? j : n;
			continue;
		}
		if (c == '\t') {
			int stop = (col / 8 + 1) * 8;

			if (stop > cols)
				stop = cols;
			while (col < stop) {
				bputs(screen, " ", 1);
				col++;
			}
			continue;
		}
		if (c < 0x20 || c == 0x7f)
			continue;
		changed = opt_diff && (i >= oldn || (unsigned char)old[i] != c);
		if (changed && !rev) {
			bputs(screen, "\033[7m", 4);
			rev = 1;
		} else if (!changed && rev) {
			bputs(screen, "\033[27m", 5);
			rev = 0;
		}
		bputs(screen, (const char *)&c, 1);
		if ((c & 0xc0) != 0x80)
			col++;
		/* the rest of a UTF-8 character takes no further column */
		while (i + 1 < n && ((unsigned char)s[i + 1] & 0xc0) == 0x80)
			bputs(screen, s + ++i, 1);
	}
	if (rev)
		bputs(screen, "\033[27m", 5);
}

static void
draw(char **argv, const struct buf *out, const struct buf *prev, double secs, int cols, int rows)
{
	struct buf screen = { 0, 0, 0 };
	char title[512], host[128] = "", when[64];
	const char *start = out->p ? out->p : "", *pstart = prev->p ? prev->p : "";
	size_t len;
	int line = opt_notitle ? 0 : 2, i;
	time_t now = time(NULL);

	bputs(&screen, "\033[H", 3);
	if (!opt_notitle) {
		char cmd[256];
		int w, tl, rl;

		cmd[0] = 0;
		for (i = opt_exec ? 0 : 2; argv[i]; i++) {
			if (cmd[0])
				strncat(cmd, " ", sizeof cmd - strlen(cmd) - 1);
			strncat(cmd, argv[i], sizeof cmd - strlen(cmd) - 1);
		}
		gethostname(host, sizeof host - 1);
		strftime(when, sizeof when, "%a %b %e %H:%M:%S %Y", localtime(&now));
		tl = snprintf(title, sizeof title, "Every %.1fs: %s", secs, cmd);
		rl = (int)strlen(host) + 2 + (int)strlen(when);
		bputs(&screen, title, (size_t)(tl < cols ? tl : cols));
		w = tl;
		if (cols - rl > tl) {
			char right[256];

			while (w < cols - rl) {
				bputs(&screen, " ", 1);
				w++;
			}
			snprintf(right, sizeof right, "%s: %s", host, when);
			bputs(&screen, right, strlen(right));
		}
		bputs(&screen, "\033[K\r\n\033[K\r\n", 9);
	}
	{
		const char *p = start, *q = pstart;

		while (*p && line < rows) {
			const char *nl = strchr(p, '\n'), *qn = strchr(q, '\n');

			len = nl ? (size_t)(nl - p) : strlen(p);
			draw_line(p, len, q, qn ? (size_t)(qn - q) : strlen(q), cols, &screen);
			bputs(&screen, "\033[K", 3);
			line++;
			if (line < rows)
				bputs(&screen, "\r\n", 2);
			if (!nl)
				break;
			p = nl + 1;
			q = qn ? qn + 1 : q + strlen(q);
		}
	}
	bputs(&screen, "\033[J", 3);
	fwrite(screen.p, 1, screen.len, stdout);
	fflush(stdout);
	free(screen.p);
}

static void
usage(FILE *f)
{
	fputs("Usage: watch [-bdegptx] [-n seconds] command [argument ...]\n"
	      "  -n, --interval SEC   seconds between runs (default 2)\n"
	      "  -d, --differences    show what changed since the last run\n"
	      "  -t, --no-title       no header\n"
	      "  -e, --errexit        stop when the command fails\n"
	      "  -g, --chgexit        stop when the output changes\n"
	      "  -b, --beep           beep when the command fails\n"
	      "  -c, --color          pass the command's colour sequences\n"
	      "  -p, --precise        count the interval from the start of a run\n"
	      "  -x, --exec           run the command directly, not through the shell\n"
	      "  -v, --version        print the version\n"
	      "  -h, --help           this text\n"
	      "Keys: q quits, space runs the command now.\n", f);
}

int
main(int argc, char **argv)
{
	static const struct option lo[] = {
		{ "interval", required_argument, 0, 'n' }, { "differences", optional_argument, 0, 'd' },
		{ "no-title", no_argument, 0, 't' }, { "errexit", no_argument, 0, 'e' },
		{ "chgexit", no_argument, 0, 'g' }, { "beep", no_argument, 0, 'b' },
		{ "color", no_argument, 0, 'c' }, { "precise", no_argument, 0, 'p' },
		{ "exec", no_argument, 0, 'x' }, { "version", no_argument, 0, 'v' },
		{ "help", no_argument, 0, 'h' }, { 0, 0, 0, 0 }
	};
	struct buf out = { 0, 0, 0 }, prev = { 0, 0, 0 };
	char **cmd, *joined = 0;
	char *args[4];
	struct sigaction sa;
	int c, first = 1, cols, rows, exitcode = 0;

	while ((c = getopt_long(argc, argv, "+bcd::eghn:ptvx", lo, 0)) != -1) {
		switch (c) {
		case 'n':
			interval = atof(optarg);
			if (interval < 0.1)
				interval = 0.1;
			break;
		case 'd': opt_diff = 1; break;
		case 't': opt_notitle = 1; break;
		case 'e': opt_errexit = 1; break;
		case 'g': opt_chgexit = 1; break;
		case 'b': opt_beep = 1; break;
		case 'c': opt_color = 1; break;
		case 'p': opt_precise = 1; break;
		case 'x': opt_exec = 1; break;
		case 'v':
			printf("watch %s (UP-Term)\n", VERSION);
			return 0;
		case 'h':
			usage(stdout);
			return 0;
		default:
			usage(stderr);
			return 1;
		}
	}
	if (optind >= argc) {
		usage(stderr);
		return 1;
	}
	if (opt_exec) {
		cmd = argv + optind;
	} else {
		size_t n = 1;
		int i;

		for (i = optind; i < argc; i++)
			n += strlen(argv[i]) + 1;
		joined = calloc(n, 1);
		for (i = optind; i < argc; i++) {
			if (i > optind)
				strcat(joined, " ");
			strcat(joined, argv[i]);
		}
		args[0] = "sh";
		args[1] = "-c";
		args[2] = joined;
		args[3] = 0;
		cmd = args;
	}

	memset(&sa, 0, sizeof sa);
	sa.sa_handler = on_signal;
	sigaction(SIGINT, &sa, 0);
	sigaction(SIGTERM, &sa, 0);
	sigaction(SIGHUP, &sa, 0);
	sigaction(SIGWINCH, &sa, 0);

	enter_screen();
	while (!quit) {
		struct timeval t0, t1;
		int status;
		double wait;

		gettimeofday(&t0, 0);
		screen_size(&cols, &rows);
		status = run(cmd, &out);
		if (quit)
			break;
		winch = 0;
		screen_size(&cols, &rows);
		draw(cmd, &out, &prev, interval, cols, rows);
		if (!first && opt_chgexit && (out.len != prev.len || memcmp(out.p ? out.p : "", prev.p ? prev.p : "", out.len))) {
			break;
		}
		if (status != 0 && (opt_errexit || opt_beep)) {
			if (opt_beep)
				fputs("\007", stdout);
			if (opt_errexit) {
				char key;

				fputs("\033[0m\033[24;1H\033[7mCommand exited with a non-zero status, press a key to exit\033[0m", stdout);
				fflush(stdout);
				if (have_tio)
					(void)read(0, &key, 1);
				exitcode = 8;
				break;
			}
			fflush(stdout);
		}
		first = 0;
		/* the output of this run is the next run's "before" */
		prev.len = 0;
		if (out.p)
			bputs(&prev, out.p, out.len);
		gettimeofday(&t1, 0);
		wait = interval;
		if (opt_precise)
			wait -= (t1.tv_sec - t0.tv_sec) + (t1.tv_usec - t0.tv_usec) / 1e6;
		while (wait > 0 && !quit) {
			fd_set rd;
			struct timeval tv, s0, s1;
			int r;

			FD_ZERO(&rd);
			if (have_tio)
				FD_SET(0, &rd);
			tv.tv_sec = (long)wait;
			tv.tv_usec = (long)((wait - (long)wait) * 1e6);
			gettimeofday(&s0, 0);
			r = select(have_tio ? 1 : 0, have_tio ? &rd : 0, 0, 0, &tv);
			gettimeofday(&s1, 0);
			if (r > 0) {
				char key;

				if (read(0, &key, 1) == 1) {
					if (key == 'q' || key == 'Q')
						quit = 1;
					if (key == ' ')
						break;
				}
			}
			if (winch) {
				winch = 0;
				screen_size(&cols, &rows);
				draw(cmd, &out, &prev, interval, cols, rows);
			}
			if (r == 0)
				break;
			wait -= (s1.tv_sec - s0.tv_sec) + (s1.tv_usec - s0.tv_usec) / 1e6;
		}
	}
	leave_screen();
	return exitcode;
}
