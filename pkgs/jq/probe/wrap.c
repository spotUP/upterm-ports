/* Probe (jq heap hunt 2026-10-15): --wrap malloc/calloc/realloc/free.
 * Keeps a table of live blocks and a ring of the last events; on a free
 * or realloc of a pointer whose ixemul header is bad (mem-8, mem-4 !=
 * 0x55555555) or that this table never handed out, it writes the
 * evidence to stderr and to T:jqwrap.log and exits 99 (no requester).
 * Caller addresses are written as offsets from __wrap_free, frames
 * from the a6 chain (build with -fno-omit-frame-pointer). */
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

void *__real_malloc(size_t);
void *__real_calloc(size_t, size_t);
void *__real_realloc(void *, size_t);
void __real_free(void *);
void __wrap_free(void *p);

#define NLIVE 8192
#define NRING 48
static void *live[NLIVE];
static size_t livesz[NLIVE];
struct ev { char op; void *p; size_t n; long c[8]; };
static struct ev ring[NRING];
static unsigned rpos;
static int busy;

static long rel(void *a) { return (long)((char *)a - (char *)&__wrap_free); }

static void frames(long *c)
{
	void **fp = __builtin_frame_address(0);
	char *lo = (char *)fp, *hi = lo + 262144;
	int i;
	for (i = 0; i < 8; i++) {
		if ((char *)fp < lo || (char *)fp >= hi || ((long)fp & 1)) { for (; i < 8; i++) c[i] = 0; break; }
		c[i] = rel(fp[1]);
		fp = (void **)fp[0];
	}
}

static unsigned h(void *p) { return ((unsigned long)p >> 2) * 2654435761u % NLIVE; }
static int find(void *p)
{
	unsigned i = h(p), k;
	for (k = 0; k < NLIVE; k++, i = (i + 1) % NLIVE)
		if (live[i] == p) return (int)i; else if (!live[i]) return -1;
	return -1;
}
static void add(void *p, size_t n)
{
	unsigned i = h(p), k;
	if (!p) return;
	for (k = 0; k < NLIVE; k++, i = (i + 1) % NLIVE)
		if (!live[i] || live[i] == (void *)1) { live[i] = p; livesz[i] = n; return; }
}
static void del(int i) { live[i] = (void *)1; } /* tombstone */

static void rec(char op, void *p, size_t n)
{
	struct ev *e = &ring[rpos++ % NRING];
	e->op = op; e->p = p; e->n = n; frames(e->c);
}

static void dump(FILE *f, const char *why, void *p)
{
	unsigned i;
	unsigned long *w = (unsigned long *)((char *)p - 16);
	long c[8];
	frames(c);
	fprintf(f, "JQWRAP %s ptr=%p known=%d frames=%lx %lx %lx %lx %lx %lx %lx\n", why, p, find(p) >= 0, c[1], c[2], c[3], c[4], c[5], c[6], c[7]);
	if (!((long)p & 1))
		fprintf(f, "JQWRAP hdr %08lx %08lx %08lx %08lx | %08lx %08lx\n", w[0], w[1], w[2], w[3], w[4], w[5]);
	for (i = 0; i < NRING; i++) {
		struct ev *e = &ring[(rpos + i) % NRING];
		if (e->op)
			fprintf(f, "JQWRAP ev %c %p %lu %lx %lx %lx %lx\n", e->op, e->p, (unsigned long)e->n, e->c[0], e->c[1], e->c[2], e->c[3]);
	}
}

static void check(const char *why, void *p)
{
	unsigned long *w = (unsigned long *)p;
	int bad = ((long)p & 1) || w[-1] != 0x55555555ul || w[-2] != 0x55555555ul;
	if (bad || find(p) < 0) {
		FILE *f;
		busy = 1;
		if (!bad) {
			long c[8]; frames(c);
			fprintf(stderr, "JQWRAP unknown %s ptr=%p frames=%lx %lx %lx %lx\n", why, p, c[0], c[1], c[2], c[3]);
			busy = 0;
			return;
		}
		dump(stderr, why, p);
		f = fopen("T:jqwrap.log", "w");
		if (f) { dump(f, why, p); fclose(f); }
		_exit(99);
	}
}

void *__wrap_malloc(size_t n)
{
	void *p = __real_malloc(n);
	if (!busy) { add(p, n); rec('m', p, n); }
	return p;
}
void *__wrap_calloc(size_t a, size_t b)
{
	void *p = __real_calloc(a, b);
	if (!busy) { add(p, a * b); rec('c', p, a * b); }
	return p;
}
void *__wrap_realloc(void *o, size_t n)
{
	void *p;
	int i;
	if (o && !busy) check("realloc-bad", o);
	p = __real_realloc(o, n);
	if (!busy && p) {
		if (o && (i = find(o)) >= 0) del(i);
		add(p, n); rec('r', p, n);
	}
	return p;
}
void __wrap_free(void *p)
{
	int i;
	if (!p) return;
	if (!busy) {
		check("free-bad", p);
		if ((i = find(p)) >= 0) del(i);
		rec('f', p, 0);
	}
	__real_free(p);
}

#include <stdarg.h>
void probe_log(const char *fmt, ...)
{
	FILE *f;
	va_list ap;
	busy++;
	f = fopen("T:jqprobe.log", "a");
	if (f) { va_start(ap, fmt); vfprintf(f, fmt, ap); va_end(ap); fclose(f); }
	busy--;
}
