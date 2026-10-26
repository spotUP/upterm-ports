/* rows_test.c UPKG: unit test of libopkg/upkg_rows.c (patches/0029), built by check/rows.sh.
 * upkg_rows.c is included here, with stubs for the package hash, the command table and the
 * list text, so the parser runs over fixture lists and upkg_rows_run runs without opkg.
 * Exit 0 and one [OK] line on success. */
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "upkg_rows.c"

void *xmalloc(size_t n) { void *p = malloc(n ? n : 1); if (!p) abort(); return p; }
void *xcalloc(size_t a, size_t b) { void *p = calloc(a ? a : 1, b ? b : 1); if (!p) abort(); return p; }
void *xrealloc(void *o, size_t n) { void *p = realloc(o, n ? n : 1); if (!p) abort(); return p; }
char *xstrdup(const char *s) { return strcpy(xmalloc(strlen(s) + 1), s); }
void sprintf_alloc(char **str, const char *fmt, ...)
{
    va_list ap;
    char buf[512];

    va_start(ap, fmt);
    vsnprintf(buf, sizeof buf, fmt, ap);
    va_end(ap);
    *str = xstrdup(buf);
}

/* fixtures: what upkg_browse_list(0..3) print */
static const char *lists[4] = {
    "alpha - 1.0 - Plain add-on\n"
    "bravo - 2.0 - Added by the last update\n"
    "charlie - 3.1 - Installed and current\n"
    "delta - 4.0 - Installed, newer in the feed\n"
    "echo - 5.0\n"
    "alphabet - 9.9 - Name that starts like alpha\n"
    "garbage line without a separator\n",
    "charlie - 3.1 - Installed and current\n"
    "delta - 3.0 - Installed, newer in the feed\n",
    "delta - 3.0 - 4.0\n",
    "bravo - 2.0 - Added by the last update\n"
    "charlie - 3.1 - Installed and current\n",
};
static int list_calls, exec_calls, find_calls, deinit_calls, init_calls, feeds_calls, status_calls, sink_set, sink_cleared;
static const char *exec_name;
static int exec_rc;
static int order_ok = 1;

char *upkg_browse_list(int which) { list_calls++; return xstrdup(lists[which]); }
static opkg_cmd_t dummy_cmd;
opkg_cmd_t *opkg_cmd_find(const char *name)
{
    find_calls++;
    return !strcmp(name, "install") || !strcmp(name, "remove") || !strcmp(name, "upgrade") ? &dummy_cmd : NULL;
}
int opkg_cmd_exec(opkg_cmd_t *cmd, int argc, const char **argv)
{
    (void)cmd; (void)argc;
    exec_calls++;
    exec_name = argv[0];
    if (!sink_set || sink_cleared)
        order_ok = 0;           /* the sink must be on while the command runs */
    return exec_rc;
}
void pkg_hash_deinit(void) { deinit_calls++; }
void pkg_hash_init(void) { init_calls++; }
int pkg_hash_load_feeds(void) { feeds_calls++; return 0; }
int pkg_hash_load_status_files(void) { status_calls++; return 0; }
void upkg_wrap_flush(void) {}
static void sink(const char *t, size_t n) { (void)t; (void)n; }
void upkg_set_sink(upkg_sink_fn fn)
{
    if (fn) { sink_set = 1; sink_cleared = 0; } else sink_cleared = 1;
}

#define CHECK(c) do { if (!(c)) { fprintf(stderr, "[FAIL] rows_test.c:%d: %s\n", __LINE__, #c); exit(1); } } while (0)

static const upkg_row_t *by_name(const upkg_rows_t *r, const char *name)
{
    size_t i;

    for (i = 0; i < r->n; i++)
        if (!strcmp(r->row[i].name, name))
            return &r->row[i];
    return NULL;
}

static void expect(const upkg_rows_t *r, const char *name, upkg_row_kind_t kind, const char *inst, const char *avail,
                   const char *desc, const char *status)
{
    const upkg_row_t *row = by_name(r, name);
    char *s;

    if (!row) { fprintf(stderr, "[FAIL] no row %s\n", name); exit(1); }
    CHECK(row->kind == kind);
    CHECK(!strcmp(row->installed, inst));
    CHECK(!strcmp(row->available, avail));
    CHECK(!strcmp(row->desc, desc));
    s = upkg_rows_status(row);
    if (strcmp(s, status)) { fprintf(stderr, "[FAIL] %s status \"%s\", wanted \"%s\"\n", name, s, status); exit(1); }
    free(s);
}

int main(void)
{
    upkg_rows_t rows = {0};
    size_t n, i;

    /* the parser, over the four fixture lists: all four kinds, a name that is a prefix of another, a row
     * with no description, and a line without " - " that makes no row */
    n = upkg_rows_load(&rows);
    CHECK(list_calls == 4);
    CHECK(n == 6 && rows.n == 6);
    expect(&rows, "alpha", UPKG_ROW_AVAILABLE, "", "1.0", "Plain add-on", "available 1.0");
    expect(&rows, "alphabet", UPKG_ROW_AVAILABLE, "", "9.9", "Name that starts like alpha", "available 9.9");
    expect(&rows, "bravo", UPKG_ROW_NEW, "", "2.0", "Added by the last update", "new 2.0");
    expect(&rows, "charlie", UPKG_ROW_INSTALLED, "3.1", "3.1", "Installed and current", "installed 3.1");
    expect(&rows, "delta", UPKG_ROW_UPGRADE, "3.0", "4.0", "Installed, newer in the feed", "upgrade 3.0 to 4.0");
    expect(&rows, "echo", UPKG_ROW_AVAILABLE, "", "5.0", "", "available 5.0");
    CHECK(!strcmp(rows.row[0].name, "alpha") && !strcmp(rows.row[4].name, "echo") && !strcmp(rows.row[5].name, "alphabet"));   /* order of the full list */

    /* an empty list and a NULL list make no rows and do not crash */
    upkg_rows_parse(&rows, "", NULL, NULL, NULL);
    CHECK(rows.n == 0);
    upkg_rows_parse(&rows, NULL, NULL, NULL, NULL);
    CHECK(rows.n == 0);
    n = upkg_rows_load(&rows);
    CHECK(n == 6);

    /* run: the command runs once on the name with the sink on, the hash is rebuilt, the rows are loaded again */
    list_calls = 0;
    exec_rc = 7;
    CHECK(upkg_rows_run(&rows, "install", "alpha", sink) == 7);
    CHECK(exec_calls == 1 && !strcmp(exec_name, "alpha"));
    CHECK(order_ok && sink_set && sink_cleared);
    CHECK(deinit_calls == 1 && init_calls == 1 && feeds_calls == 1 && status_calls == 1);
    CHECK(list_calls == 4 && rows.n == 6);
    exec_rc = 0;
    CHECK(upkg_rows_run(&rows, "remove", "charlie", NULL) == 0);
    CHECK(exec_calls == 2 && deinit_calls == 2);
    CHECK(upkg_rows_run(&rows, "upgrade", "delta", sink) == 0);
    CHECK(exec_calls == 3);
    /* an unknown command runs nothing and rebuilds nothing */
    CHECK(upkg_rows_run(&rows, "frobnicate", "alpha", sink) == -1);
    CHECK(exec_calls == 3 && deinit_calls == 3);

    for (i = 0; i < 3; i++)
        upkg_rows_free(&rows);
    CHECK(rows.n == 0 && rows.row == NULL);
    printf("[OK] upkg_rows: four row kinds parsed, install/remove/upgrade run with the sink and rebuild the rows\n");
    return 0;
}
