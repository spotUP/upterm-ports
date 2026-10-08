/* ptyrun -- run a program on a pseudo-terminal and record what it draws
 * (the tty cases of vtcon's tools/rig/userland_rig.py: less, nano, ...).
 *
 *   ptyrun [-s COLSxROWS] [-t SECONDS] KEYS OUT COMMAND [ARG...]
 *
 * Words NAME=VALUE before COMMAND go into its environment (as env(1)
 * takes them): a case can set LESS, say, without a shell.
 * COMMAND runs on the slave of a free /dev/ptyXY (its own session, the
 * slave as controlling terminal and as fds 0-2, the window size given;
 * default 80x24), found through $PATH. Everything it writes is appended to
 * OUT. KEYS is a file of steps, one per line, "MS TEXT": wait until the
 * program has written nothing for MS milliseconds, then type TEXT on the
 * master. TEXT takes \r \n \t \e \\ and \xHH. Before each step the byte
 * count of OUT so far goes to OUT.marks ("<step> <bytes>"), so the screen
 * at that moment can be rendered from the first <bytes> of OUT.
 * After the last step ptyrun waits for the program to end (at most
 * SECONDS, default 30; then SIGKILL). It prints "exit N" (N the program's
 * status, or "killed") and exits 0, or 2 when it could not run it.
 *
 * ixemul has no fork: the child is a vfork that only sets up its own
 * kernel state and execs (setsid, open, TIOCSCTTY, dup2). */
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <termios.h>
#include <unistd.h>

static long now_ms(void)
{
    struct timeval t;
    gettimeofday(&t, 0);
    return t.tv_sec * 1000L + t.tv_usec / 1000;
}

/* "\r" "\e" "\x1b" ... into bytes; returns the length */
static int unescape(const char *s, char *out)
{
    int n = 0;
    while (*s && *s != '\n') {
        if (*s != '\\' || !s[1]) {
            out[n++] = *s++;
            continue;
        }
        s++;
        switch (*s) {
        case 'r': out[n++] = '\r'; s++; break;
        case 'n': out[n++] = '\n'; s++; break;
        case 't': out[n++] = '\t'; s++; break;
        case 'e': out[n++] = 27; s++; break;
        case 'x': {
            char hex[3] = { 0, 0, 0 };
            s++;
            if (*s) hex[0] = *s++;
            if (*s && *s != '\n') hex[1] = *s++;
            out[n++] = (char)strtol(hex, 0, 16);
            break;
        }
        default: out[n++] = *s++; break;
        }
    }
    return n;
}

static int master = -1;
static FILE *out;
static long total;

/* copy what the program wrote to OUT; 1 when something came */
static int pump(int ms)
{
    fd_set r;
    struct timeval tv;
    char buf[1024];
    int n;
    FD_ZERO(&r);
    FD_SET(master, &r);
    tv.tv_sec = ms / 1000;
    tv.tv_usec = (ms % 1000) * 1000;
    if (select(master + 1, &r, 0, 0, &tv) <= 0)
        return 0;
    n = read(master, buf, sizeof(buf));
    if (n <= 0)
        return 0;
    fwrite(buf, 1, n, out);
    fflush(out);
    total += n;
    return 1;
}

int main(int argc, char **argv)
{
    static const char c1[] = "pqrstu", c2[] = "0123456789abcdef";
    char mname[16], sname[64], line[512], text[512], marks[300];
    struct winsize ws;
    int cols = 80, rows = 24, secs = 30, i, j, st = 0, pid, step = 0, done = 0;
    FILE *keys, *mk;
    long end;

    while (argc > 1 && argv[1][0] == '-') {
        if (!strcmp(argv[1], "-s") && argc > 2)
            sscanf(argv[2], "%dx%d", &cols, &rows);
        else if (!strcmp(argv[1], "-t") && argc > 2)
            secs = atoi(argv[2]);
        else
            break;
        argv += 2;
        argc -= 2;
    }
    if (argc < 4) {
        fprintf(stderr, "usage: ptyrun [-s COLSxROWS] [-t SECONDS] KEYS OUT COMMAND [ARG...]\n");
        return 2;
    }
    while (argc > 4 && argv[3][0] != '-' && strchr(argv[3], '=')) {
        putenv(argv[3]);
        argv[3] = argv[2];
        argv[2] = argv[1];
        argv[1] = argv[0];
        argv++;
        argc--;
    }
    if (!(keys = fopen(argv[1], "r")) || !(out = fopen(argv[2], "w"))) {
        perror("ptyrun");
        return 2;
    }
    snprintf(marks, sizeof(marks), "%s.marks", argv[2]);
    if (!(mk = fopen(marks, "w"))) {
        perror(marks);
        return 2;
    }
#ifdef __APPLE__
    /* the Mac side (expected outputs): Unix 98 ptys */
    (void)c1; (void)c2; (void)i; (void)j; (void)mname;
    if ((master = posix_openpt(O_RDWR | O_NOCTTY)) < 0 || grantpt(master) || unlockpt(master)) {
        perror("ptyrun: posix_openpt");
        return 2;
    }
    snprintf(sname, sizeof(sname), "%s", ptsname(master));
#else
    for (i = 0; c1[i] && master < 0; i++)
        for (j = 0; c2[j] && master < 0; j++) {
            sprintf(mname, "/dev/pty%c%c", c1[i], c2[j]);
            master = open(mname, O_RDWR);
        }
    if (master < 0) {
        fprintf(stderr, "ptyrun: no free /dev/ptyXY: %s\n", strerror(errno));
        return 2;
    }
    strcpy(sname, mname);
    sname[5] = 't';
#endif
    memset(&ws, 0, sizeof(ws));
    ws.ws_col = cols;
    ws.ws_row = rows;
    ioctl(master, TIOCSWINSZ, &ws);

    if ((pid = vfork()) == 0) {
        int s;
        setsid();
        if ((s = open(sname, O_RDWR)) < 0)
            _exit(126);
        ioctl(s, TIOCSCTTY, 0);
        dup2(s, 0);
        dup2(s, 1);
        dup2(s, 2);
        if (s > 2)
            close(s);
        close(master);
        execvp(argv[3], argv + 3);
        _exit(127);
    }
    if (pid < 0) {
        perror("ptyrun: vfork");
        return 2;
    }

    while (fgets(line, sizeof(line), keys)) {
        char *t;
        long quiet = strtol(line, &t, 10), last;
        int n;
        if (t == line || line[0] == '#')
            continue;
        if (*t == ' ')
            t++;
        n = unescape(t, text);
        /* wait for quiet output (and at most the whole timeout) */
        last = now_ms();
        end = last + secs * 1000L;
        while (now_ms() - last < quiet && now_ms() < end) {
            if (pump(50))
                last = now_ms();
            if (waitpid(pid, &st, WNOHANG) == pid) {
                done = 1;
                break;
            }
        }
        fprintf(mk, "%d %ld\n", ++step, total);
        fflush(mk);
        if (done)
            break;
        write(master, text, n);
    }
    end = now_ms() + secs * 1000L;
    while (!done && now_ms() < end) {
        pump(100);
        if (waitpid(pid, &st, WNOHANG) == pid)
            done = 1;
    }
    while (pump(200))
        ;
    if (!done) {
        kill(pid, SIGKILL);
        waitpid(pid, &st, 0);
        printf("exit killed\n");
    } else
        printf("exit %d\n", WIFEXITED(st) ? WEXITSTATUS(st) : 128 + WTERMSIG(st));
    fprintf(mk, "end %ld\n", total);
    fclose(mk);
    fclose(out);
    return 0;
}
