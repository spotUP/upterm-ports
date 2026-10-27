/* rows_test.c UPKG: unit test of libopkg/upkg_rows.c (patches/0029), built by check/rows.sh.
 * upkg_rows.c is included here, with stubs for the package hash, the command table and the
 * list text, so the parser runs over fixture lists and upkg_rows_run runs without opkg.
 * Exit 0 and one [OK] line on success. */
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

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
static int exec_rc, exec_argc = -1;
static int order_ok = 1;

char *upkg_browse_list(int which) { list_calls++; return xstrdup(lists[which]); }
static opkg_cmd_t dummy_cmd;
opkg_cmd_t *opkg_cmd_find(const char *name)
{
    find_calls++;
    return !strcmp(name, "install") || !strcmp(name, "remove") || !strcmp(name, "upgrade") || !strcmp(name, "update") ? &dummy_cmd : NULL;
}
int opkg_cmd_exec(opkg_cmd_t *cmd, int argc, const char **argv)
{
    (void)cmd;
    exec_calls++;
    exec_argc = argc;
    exec_name = argc > 0 ? argv[0] : "";
    if (!sink_set || sink_cleared)
        order_ok = 0;           /* the sink must be on while the command runs */
    return exec_rc;
}
opkg_conf_t *opkg_config;
void pkg_hash_deinit(void) { deinit_calls++; }
void pkg_hash_init(void) { init_calls++; }
int pkg_hash_load_feeds(void) { feeds_calls++; return 0; }
int pkg_hash_load_status_files(void) { status_calls++; return 0; }
void upkg_wrap_flush(void) {}
/* browse launch: xsystem records the argv it was given and returns the exit code the test sets */
static int sys_calls, sys_rc, sys_deinit_before;
static char sys_line[256];
int xsystem(const char *argv[])
{
    sys_calls++;
    sys_deinit_before = deinit_calls;
    snprintf(sys_line, sizeof sys_line, "%s|%s|%s", argv[0], argv[1], argv[2]);
    return sys_rc;
}
static void sink(const char *t, size_t n) { (void)t; (void)n; }
void upkg_set_sink(upkg_sink_fn fn)
{
    if (fn) { sink_set = 1; sink_cleared = 0; } else sink_cleared = 1;
}

static int lines_n;
static char lines_got[16][600];
static void line_cb(void *ctx, const char *line) { (void)ctx; snprintf(lines_got[lines_n++], sizeof lines_got[0], "%s", line); }

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

int main(int argc, char **argv)
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

    /* the window's decisions: which rows a filter shows, which buttons a row enables, the listview line */
    {
        size_t idx[16];
        char *l;

        CHECK(upkg_rows_filter(&rows, UPKG_FILTER_ALL, idx) == 6 && idx[0] == 0 && idx[5] == 5);
        CHECK(upkg_rows_filter(&rows, UPKG_FILTER_INSTALLED, idx) == 2 && idx[0] == 2 && idx[1] == 3);
        CHECK(upkg_rows_filter(&rows, UPKG_FILTER_UPGRADABLE, idx) == 1 && idx[0] == 3);
        CHECK(upkg_rows_actions(NULL) == 0);
        CHECK(upkg_rows_actions(by_name(&rows, "alpha")) == UPKG_ACT_INSTALL);
        CHECK(upkg_rows_actions(by_name(&rows, "bravo")) == UPKG_ACT_INSTALL);
        CHECK(upkg_rows_actions(by_name(&rows, "charlie")) == UPKG_ACT_REMOVE);
        CHECK(upkg_rows_actions(by_name(&rows, "delta")) == (UPKG_ACT_REMOVE | UPKG_ACT_UPGRADE));
        l = upkg_rows_label(by_name(&rows, "delta"));
        CHECK(!strcmp(l, "delta  3.0  4.0  upgradable"));
        free(l);
        l = upkg_rows_label(by_name(&rows, "alpha"));
        CHECK(!strcmp(l, "alpha  -  1.0  available"));
        free(l);
        l = upkg_rows_label(by_name(&rows, "bravo"));
        CHECK(!strcmp(l, "bravo  -  2.0  new"));
        free(l);
        l = upkg_rows_label(by_name(&rows, "charlie"));
        CHECK(!strcmp(l, "charlie  3.1  3.1  installed"));
        free(l);
    }

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
    /* a failed command reports RETURN_FAIL (20) like `upkg install` from a Shell, never the raw -1 opkg returns:
     * the Workbench window and browse print "[ERROR] ... (exit N)" with this code */
    exec_rc = -1;
    CHECK(upkg_rows_run(&rows, "install", "alpha", sink) == 20);
    CHECK(exec_calls == 4 && deinit_calls == 4);
    exec_rc = 0;
    /* an unknown command runs nothing and rebuilds nothing, and fails with the same code */
    CHECK(upkg_rows_run(&rows, "frobnicate", "alpha", sink) == 20);
    CHECK(exec_calls == 4 && deinit_calls == 4);

    /* Update runs through the same function with no package: argc 0 */
    CHECK(upkg_rows_run(&rows, "update", NULL, sink) == 0);
    CHECK(exec_calls == 5 && exec_argc == 0 && deinit_calls == 5);
    CHECK(upkg_rows_run(&rows, "install", "alpha", sink) == 0 && exec_argc == 1);

    /* bulk: Install All covers the available and new rows, Update All the upgradable ones; the command gets all names */
    {
        size_t k, want_i = 0, want_u = 0, ni, nu;
        char **bi, **bu, *t;

        for (k = 0; k < rows.n; k++) {
            want_i += rows.row[k].kind == UPKG_ROW_AVAILABLE || rows.row[k].kind == UPKG_ROW_NEW;
            want_u += rows.row[k].kind == UPKG_ROW_UPGRADE;
        }
        bi = upkg_rows_bulk_names(&rows, 'I', &ni);
        bu = upkg_rows_bulk_names(&rows, 'U', &nu);
        CHECK(ni == want_i && nu == want_u && nu == 1 && ni >= 2);
        CHECK(!strcmp(bi[0], "alpha") && !strcmp(bi[1], "bravo") && bi[ni] == NULL && !strcmp(bu[0], "delta") && bu[1] == NULL);
        CHECK(upkg_rows_run_names(&rows, "install", (int)ni, (const char **)bi, NULL) == 0);
        CHECK(exec_argc == (int)ni && !strcmp(exec_name, "alpha"));
        CHECK(upkg_rows_run_names(&rows, "upgrade", 0, NULL, NULL) == 0 && exec_argc == 0);   /* upgrade of everything: no names */
        upkg_rows_bulk_free(bi);
        upkg_rows_bulk_free(bu);
        t = upkg_rows_bulk_text('I', 3, 1258291);
        CHECK(!strcmp(t, "Install all 3 add-ons? Total download: 1.2 MB."));
        free(t);
        t = upkg_rows_bulk_text('U', 1, 500);
        CHECK(!strcmp(t, "Update all 1 add-on? Total download: 500 bytes."));
        free(t);
        t = upkg_rows_bulk_text('U', 2, 20480);
        CHECK(!strcmp(t, "Update all 2 add-ons? Total download: 20.0 KB."));
        free(t);
    }

    /* the buttons: a run disables all of them, otherwise the row's plus Update and Quit */
    CHECK(upkg_rows_buttons(1, UPKG_ACT_INSTALL | UPKG_ACT_REMOVE) == 0);
    CHECK(upkg_rows_buttons(0, 0) == (UPKG_ACT_UPDATE | UPKG_ACT_QUIT));
    CHECK(upkg_rows_buttons(0, UPKG_ACT_REMOVE) == (UPKG_ACT_REMOVE | UPKG_ACT_UPDATE | UPKG_ACT_QUIT));

    /* the log: pieces of text become lines; a line may arrive in several pieces; tab and carriage return handled */
    {
        upkg_lines_t l = { {0}, 0 };
        lines_n = 0;
        upkg_lines_put(&l, "Installing al", 13, line_cb, NULL);
        CHECK(lines_n == 0);
        upkg_lines_put(&l, "pha\r\nDone\n\nA\tB", 14, line_cb, NULL);
        CHECK(lines_n == 3 && !strcmp(lines_got[0], "Installing alpha") && !strcmp(lines_got[1], "Done") && !strcmp(lines_got[2], ""));
        upkg_lines_end(&l, line_cb, NULL);
        CHECK(lines_n == 4 && !strcmp(lines_got[3], "A       B"));
        upkg_lines_end(&l, line_cb, NULL);
        CHECK(lines_n == 4);                       /* nothing left */
    }

    /* the install-questions check, one place for browse and the window */
    {
        char dir[] = "/tmp/rows_lists.XXXXXX";
        char path[256];
        FILE *fp;

        CHECK(mkdtemp(dir) != NULL);
        snprintf(path, sizeof path, "%s/feed", dir);
        fp = fopen(path, "w");
        CHECK(fp != NULL);
        fputs("Package: asker\nUP-Term-Interactive: yes\n\nPackage: quiet\nVersion: 1\n", fp);
        fclose(fp);
        setenv("UPKG_LISTS_DIR", dir, 1);
        CHECK(upkg_rows_interactive("asker") == 1);
        CHECK(upkg_rows_interactive("quiet") == 0);
        CHECK(upkg_rows_interactive("ask") == 0);
        remove(path);
        rmdir(dir);
    }

    /* browse launch (patches/0040): the Launch line of an installed package's control file */
    {
        char dir[] = "/tmp/rows_info.XXXXXX";
        char path[256];
        FILE *fp;
        char *v;
        upkg_row_t plain = {0}, inst = {0}, upg = {0};
        int deinit_start;

        CHECK(mkdtemp(dir) != NULL);
        snprintf(path, sizeof path, "%s/charlie.control", dir);
        fp = fopen(path, "w");
        CHECK(fp != NULL);
        fputs("Package: charlie\nVersion: 3.1\nLaunch:   Work:Tools/charlie -x  \r\nDescription: d\n", fp);
        fclose(fp);
        snprintf(path, sizeof path, "%s/delta.control", dir);
        fp = fopen(path, "w");
        CHECK(fp != NULL);
        fputs("Package: delta\nVersion: 3.0\nLaunchish: no\n", fp);
        fclose(fp);
        setenv("UPKG_INFO_DIR", dir, 1);

        v = upkg_rows_launch("charlie");
        CHECK(!strcmp(v, "Work:Tools/charlie -x"));
        free(v);
        v = upkg_rows_launch("delta");               /* a field that only starts with Launch is not Launch */
        CHECK(!strcmp(v, ""));
        free(v);
        v = upkg_rows_launch("nosuch");
        CHECK(!strcmp(v, ""));
        free(v);

        upkg_rows_free(&rows);
        CHECK(upkg_rows_load(&rows) == 6);
        CHECK(!strcmp(by_name(&rows, "charlie")->launch, "Work:Tools/charlie -x"));
        CHECK(!strcmp(by_name(&rows, "delta")->launch, ""));
        CHECK(!strcmp(by_name(&rows, "alpha")->launch, ""));   /* not installed: never read */

        /* the key decision: Enter launches an installed row with Launch, Delete removes an installed row */
        plain.kind = UPKG_ROW_AVAILABLE;
        inst.kind = UPKG_ROW_INSTALLED;
        inst.launch = by_name(&rows, "charlie")->launch;
        upg.kind = UPKG_ROW_UPGRADE;
        upg.launch = (char *)"";
        CHECK(upkg_rows_key_action(0, &inst) == 'l');
        CHECK(upkg_rows_key_action(0, &upg) == 0);        /* installed, no Launch: the info box */
        CHECK(upkg_rows_key_action(0, &plain) == 0);
        CHECK(upkg_rows_key_action(127, &inst) == 'r' && upkg_rows_key_action(127, &upg) == 'r');
        CHECK(upkg_rows_key_action(127, &plain) == 0);
        CHECK(upkg_rows_key_action('r', &inst) == 0);     /* the Remove key moved to Delete */
        CHECK(upkg_rows_key_action('i', &plain) == 'i' && upkg_rows_key_action('u', &upg) == 'u');
        CHECK(upkg_rows_key_action('I', &inst) == 'I' && upkg_rows_key_action('U', &plain) == 'U');   /* Install All, Update All */
        CHECK(upkg_rows_key_action('I', NULL) == 'I' && upkg_rows_key_action('U', NULL) == 'U');     /* with no row */

        v = upkg_rows_launch_status("charlie", 5);
        CHECK(!strcmp(v, "charlie exited with code 5"));
        free(v);
        v = upkg_rows_launch_status("charlie", 0);
        CHECK(!strcmp(v, "charlie exited with code 0"));
        free(v);

        /* the run: one shell command line through xsystem, then the rows are read again */
        deinit_start = deinit_calls;
        list_calls = 0;
        sys_rc = 7;
        CHECK(upkg_rows_launch_run(&rows, "charlie", "Work:Tools/charlie -x") == 7);
        CHECK(sys_calls == 1 && !strcmp(sys_line, "sh|-c|Work:Tools/charlie -x"));
        CHECK(sys_deinit_before == deinit_start && deinit_calls == deinit_start + 1);
        CHECK(list_calls == 4 && rows.n == 6);
        CHECK(!strcmp(by_name(&rows, "charlie")->launch, "Work:Tools/charlie -x"));

        snprintf(path, sizeof path, "%s/charlie.control", dir);
        remove(path);
        snprintf(path, sizeof path, "%s/delta.control", dir);
        remove(path);
        rmdir(dir);
        unsetenv("UPKG_INFO_DIR");
    }

    /* UHC rows (patch 0043): the fixture drawer (curl current, lzx not installed, unzip 5.40 installed and 5.42 in the script)
     * is appended after the feed rows with src=uhc; a feed package of the same name keeps its own row (D3) */
    {
        const char *saved = lists[0];
        char *clash;
        size_t k, uhc_rows = 0, idx_all[16];
        const upkg_row_t *r;

        CHECK(argc == 2);
        setenv("UPKG_UHC_DIR", argv[1], 1);
        n = upkg_rows_load(&rows);
        CHECK(n == 9 && rows.n == 9);
        for (k = 0; k < rows.n; k++)
            CHECK((k < 6) == (rows.row[k].src == UPKG_SRC_OPKG));           /* feed rows first, all src=opkg */
        CHECK(!strcmp(rows.row[6].name, "curl") && !strcmp(rows.row[7].name, "lzx") && !strcmp(rows.row[8].name, "unzip"));
        r = &rows.row[6];
        CHECK(r->kind == UPKG_ROW_INSTALLED && !strcmp(r->installed, "7.10.5") && !strcmp(r->available, "7.10.5") && r->desc[0]);
        r = &rows.row[7];
        CHECK(r->kind == UPKG_ROW_AVAILABLE && !strcmp(r->installed, "") && !strcmp(r->available, "1.21r") && !strcmp(r->launch, ""));
        r = &rows.row[8];
        CHECK(r->kind == UPKG_ROW_UPGRADE && !strcmp(r->installed, "5.40") && !strcmp(r->available, "5.42")
              && !strcmp(r->desc, "Extractor for zip-archives"));
        CHECK(upkg_rows_actions(r) == (UPKG_ACT_REMOVE | UPKG_ACT_UPGRADE));
        CHECK(upkg_rows_filter(&rows, UPKG_FILTER_UPGRADABLE, idx_all) == 2);   /* delta (feed) and unzip (uhc) */
        for (k = 0; k < rows.n; k++)
            uhc_rows += rows.row[k].src == UPKG_SRC_UHC;
        CHECK(uhc_rows == 3);

        /* a feed package called unzip: both rows stay */
        clash = xmalloc(strlen(saved) + 64);
        strcpy(clash, saved);
        strcat(clash, "unzip - 6.0 - Feed copy\n");
        lists[0] = clash;
        n = upkg_rows_load(&rows);
        lists[0] = saved;
        free(clash);
        CHECK(n == 10);
        CHECK(!strcmp(rows.row[6].name, "unzip") && rows.row[6].src == UPKG_SRC_OPKG && !strcmp(rows.row[6].available, "6.0"));
        CHECK(!strcmp(rows.row[9].name, "unzip") && rows.row[9].src == UPKG_SRC_UHC && !strcmp(rows.row[9].available, "5.42"));

        /* no drawer: only the feed rows */
        setenv("UPKG_UHC_DIR", "/nonexistent/uhc/drawer", 1);
        CHECK(upkg_rows_load(&rows) == 6);
        unsetenv("UPKG_UHC_DIR");
    }

    for (i = 0; i < 3; i++)
        upkg_rows_free(&rows);
    CHECK(rows.n == 0 && rows.row == NULL);
    printf("[OK] upkg_rows: four row kinds parsed, filters and button actions decided, install/remove/upgrade run with the sink and rebuild the rows\n");
    return 0;
}
