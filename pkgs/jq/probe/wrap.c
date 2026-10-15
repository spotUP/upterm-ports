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
static long livefr[NLIVE][6];
static void frames(long *c);
static void add(void *p, size_t n)
{
	unsigned i = h(p), k;
	long c[8];
	if (!p) return;
	for (k = 0; k < NLIVE; k++, i = (i + 1) % NLIVE)
		if (!live[i] || live[i] == (void *)1) { live[i] = p; livesz[i] = n; frames(c); memcpy(livefr[i], c + 1, sizeof livefr[i]); return; }
}
/* freed blocks of the 49..64 byte class (ixemul cache class 3): their
 * first word is ixemul's cache link, so it must stay 0 or a pointer */
#define NFL 64
struct fl { void *p; size_t n; long mfr[6]; long ffr[6]; };
static struct fl fl[NFL];
static int nfl, flhit;
static int cls64(size_t n) { n = (n + 3) & ~3; return n >= 49 && n <= 64; }
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

/* watch: one word (jq->bc), checked after every heap event and stage */
void **probe_watch;
static void *watchval;
static int watchhits;
void probe_watch_set(void **a) { probe_watch = a; watchval = *a; }
static void flcheck(const char *where, void *q, size_t qn)
{
	int i, j;
	FILE *f;
	long c[8];
	if (flhit) return;
	for (i = 0; i < nfl; i++) {
		unsigned long v = *(unsigned long *)fl[i].p;
		if ((v & 1) || (v && v < 0x1000)) {
			flhit = 1; busy++;
			frames(c);
			f = fopen("T:jqfl.log", "a");
			if (f) {
				fprintf(f, "JQFL hit at %s q=%p qn=%lu block=%p n=%lu word0=%08lx words=%08lx %08lx %08lx %08lx\n", where, q, (unsigned long)qn, fl[i].p, (unsigned long)fl[i].n, v,
					((unsigned long *)fl[i].p)[1], ((unsigned long *)fl[i].p)[2], ((unsigned long *)fl[i].p)[3], ((unsigned long *)fl[i].p)[4]);
				fprintf(f, "JQFL now frames=%lx %lx %lx %lx %lx %lx %lx\n", c[1], c[2], c[3], c[4], c[5], c[6], c[7]);
				fprintf(f, "JQFL malloc frames=%lx %lx %lx %lx %lx %lx\n", fl[i].mfr[0], fl[i].mfr[1], fl[i].mfr[2], fl[i].mfr[3], fl[i].mfr[4], fl[i].mfr[5]);
				fprintf(f, "JQFL free frames=%lx %lx %lx %lx %lx %lx\n", fl[i].ffr[0], fl[i].ffr[1], fl[i].ffr[2], fl[i].ffr[3], fl[i].ffr[4], fl[i].ffr[5]);
				for (j = 0; j < NRING; j++) {
					struct ev *e = &ring[(rpos + j) % NRING];
					if (e->op)
						fprintf(f, "JQFL ev %c %p %lu %lx %lx %lx %lx %lx %lx\n", e->op, e->p, (unsigned long)e->n, e->c[0], e->c[1], e->c[2], e->c[3], e->c[4], e->c[5]);
				}
				fclose(f);
			}
			busy--;
			return;
		}
	}
}
static void fldel(void *p)
{
	int i;
	for (i = 0; i < nfl; i++)
		if (fl[i].p == p) { fl[i] = fl[--nfl]; return; }
}
static void fladd(void *p, int li)
{
	long c[8];
	if (nfl >= NFL) return;
	fl[nfl].p = p; fl[nfl].n = livesz[li];
	memcpy(fl[nfl].mfr, livefr[li], sizeof fl[nfl].mfr);
	frames(c); memcpy(fl[nfl].ffr, c + 1, sizeof fl[nfl].ffr);
	nfl++;
}
static void watch(const char *where, void *p, size_t n)
{
	if (!busy) flcheck(where, p, n);
	FILE *f;
	unsigned i;
	long c[8];
	if (!probe_watch || *probe_watch == watchval || watchhits > 3) return;
	busy++;
	watchhits++;
	frames(c);
	f = fopen("T:jqwatch.log", "a");
	if (f) {
		fprintf(f, "JQWATCH change at %s p=%p n=%lu old=%p new=%p frames=%lx %lx %lx %lx %lx %lx %lx\n", where, p, (unsigned long)n, watchval, *probe_watch, c[1], c[2], c[3], c[4], c[5], c[6], c[7]);
		for (i = 0; i < NRING; i++) {
			struct ev *e = &ring[(rpos + i) % NRING];
			if (e->op)
				fprintf(f, "JQWATCH ev %c %p %lu %lx %lx %lx %lx %lx %lx\n", e->op, e->p, (unsigned long)e->n, e->c[0], e->c[1], e->c[2], e->c[3], e->c[4], e->c[5]);
		}
		fclose(f);
	}
	watchval = *probe_watch;
	busy--;
}
void probe_stage(const char *s) { watch(s, 0, 0); }

void *__wrap_malloc(size_t n)
{
	void *p;
	watch("pre-malloc", 0, n);
	p = __real_malloc(n);
	if (!busy) { fldel(p); add(p, n); rec('m', p, n); }
	watch("malloc", p, n);
	return p;
}
void *__wrap_calloc(size_t a, size_t b)
{
	void *p = __real_calloc(a, b);
	if (!busy) { fldel(p); add(p, a * b); rec('c', p, a * b); }
	watch("calloc", p, a * b);
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
		fldel(p); add(p, n); rec('r', p, n);
	}
	watch("realloc", p, n);
	return p;
}
void __wrap_free(void *p)
{
	int i;
	if (!p) return;
	watch("pre-free", p, 0);
	if (!busy) {
		check("free-bad", p);
		if ((i = find(p)) >= 0) { if (cls64(livesz[i])) fladd(p, i); del(i); }
		rec('f', p, 0);
	}
	__real_free(p);
	watch("free", p, 0);
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
/* refcount op on a block that sits in the freed list: log the caller */
static int rchits;
void probe_refcheck(void *p, int d)
{
	int i;
	long c[8];
	FILE *f;
	if (busy || rchits >= 4) return;
	for (i = 0; i < nfl; i++) if (fl[i].p == p) break;
	if (i == nfl) return;
	rchits++; busy++;
	frames(c);
	f = fopen("T:jqrc.log", "a");
	if (f) {
		fprintf(f, "JQRC %s block=%p n=%lu word0=%08lx words=%08lx %08lx %08lx\n", d > 0 ? "inc" : "dec", p, (unsigned long)fl[i].n,
			((unsigned long *)p)[0], ((unsigned long *)p)[1], ((unsigned long *)p)[2], ((unsigned long *)p)[3]);
		fprintf(f, "JQRC now frames=%lx %lx %lx %lx %lx %lx %lx\n", c[1], c[2], c[3], c[4], c[5], c[6], c[7]);
		fprintf(f, "JQRC malloc frames=%lx %lx %lx %lx %lx %lx\n", fl[i].mfr[0], fl[i].mfr[1], fl[i].mfr[2], fl[i].mfr[3], fl[i].mfr[4], fl[i].mfr[5]);
		fprintf(f, "JQRC free frames=%lx %lx %lx %lx %lx %lx\n", fl[i].ffr[0], fl[i].ffr[1], fl[i].ffr[2], fl[i].ffr[3], fl[i].ffr[4], fl[i].ffr[5]);
		fclose(f);
	}
	busy--;
}
