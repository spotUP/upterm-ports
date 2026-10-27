/* uhc_run_test.c: unit test of the U4 install runner and the U5 remove parser in libopkg/upkg_uhc.c, built by
 * check/uhc_run.sh. ALL_DIR holds every script of the up-uhc archive (check/uhc/all, 11 files); SCRATCH is a work
 * directory. xsystem is a stub that records the argv and returns the exit code the test sets. */
#include <dirent.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>

#include "upkg_uhc.c"

void *xmalloc(size_t n) { void *p = malloc(n ? n : 1); if (!p) abort(); return p; }
void *xrealloc(void *o, size_t n) { void *p = realloc(o, n ? n : 1); if (!p) abort(); return p; }
char *xstrdup(const char *s) { return strcpy(xmalloc(strlen(s) + 1), s); }
void sprintf_alloc(char **str, const char *fmt, ...)
{
    va_list ap;
    char buf[1024];

    va_start(ap, fmt);
    vsnprintf(buf, sizeof buf, fmt, ap);
    va_end(ap);
    *str = xstrdup(buf);
}

static char x_argv[4][1024];
static int x_n, x_rc, x_calls;
int xsystem(const char *argv[])
{
    x_n = 0;
    while (argv[x_n] && x_n < 4) { snprintf(x_argv[x_n], sizeof x_argv[x_n], "%s", argv[x_n]); x_n++; }
    x_calls++;
    return x_rc;
}

static int fails;
#define CHECK(c) do { if (!(c)) { fprintf(stderr, "[FAIL] uhc_run: line %d: %s\n", __LINE__, #c); fails++; } } while (0)

static void put(const char *path, const char *text)
{
    FILE *fp = fopen(path, "w");
    if (!fp) { perror(path); exit(2); }
    fputs(text, fp);
    fclose(fp);
}

static int has(char **f, size_t n, const char *p)
{
    size_t i;
    for (i = 0; i < n; i++) if (!strcmp(f[i], p)) return 1;
    return 0;
}

int main(int argc, char **argv)
{
    char env[1100], p[1500], p2[1500], *s, **f;
    const char *all = argv[1];
    size_t n, skipped, scripts = 0, parsed = 0;
    DIR *d;
    struct dirent *de;
    char refused[512] = "";
    int ac, ran, rc;
    char *args[6];

    if (argc != 3) { fprintf(stderr, "usage: uhc_run_test ALL_DIR SCRATCH\n"); return 2; }
    mkdir(argv[2], 0700);

    /* --- U5: the ENV variables UHC/EXTBIN and UHC/EXTDOC as the archive's startup sets them --- */
    snprintf(env, sizeof env, "%s/env/", argv[2]);
    snprintf(p, sizeof p, "%s/env", argv[2]); mkdir(p, 0700);
    snprintf(p, sizeof p, "%s/env/UHC", argv[2]); mkdir(p, 0700);
    snprintf(p, sizeof p, "%s/env/UHC/EXTBIN", argv[2]); put(p, "UHC:C/\n");
    snprintf(p, sizeof p, "%s/env/UHC/EXTDOC", argv[2]); put(p, "UHC:Docs/\n");
    setenv("UPKG_UHC_ENV", env, 1);

    /* every shipped script: how many name at least one file; the rest are refused */
    snprintf(p, sizeof p, "%s", all);
    d = opendir(p);
    CHECK(d != NULL);
    while (d && (de = readdir(d)) != NULL) {
        if (de->d_name[0] == '.') continue;
        scripts++;
        snprintf(p2, sizeof p2, "%s/%s", all, de->d_name);
        n = upkg_uhc_files(p2, &f, &skipped);
        printf("  parse %-8s files=%lu skipped=%lu\n", de->d_name, (unsigned long)n, (unsigned long)skipped);
        if (n) parsed++;
        else { strncat(refused, de->d_name, sizeof refused - strlen(refused) - 2); strcat(refused, " "); }
        upkg_uhc_files_free(f, n);
    }
    if (d) closedir(d);
    printf("  scripts=%lu parse-nonempty=%lu refused: %s\n", (unsigned long)scripts, (unsigned long)parsed, refused);
    CHECK(scripts == 11);
    CHECK(parsed == 10);
    CHECK(!strcmp(refused, "xdms "));

    /* known cases */
    snprintf(p, sizeof p, "%s/unzip", all);
    n = upkg_uhc_files(p, &f, &skipped);
    CHECK(n == 4 && skipped == 0);
    CHECK(has(f, n, "UHC:Docs/README") && has(f, n, "UHC:Docs/README.AMI") && has(f, n, "UHC:C/UnZip") && has(f, n, "UHC:Docs/unzip.doc"));
    upkg_uhc_files_free(f, n);
    snprintf(p, sizeof p, "%s/curl", all);
    n = upkg_uhc_files(p, &f, &skipped);
    CHECK(n == 1 && has(f, n, "UHC:C/curl"));              /* a file target: not <dir>/curl.020 */
    upkg_uhc_files_free(f, n);
    snprintf(p, sizeof p, "%s/lzx", all);
    n = upkg_uhc_files(p, &f, &skipped);
    CHECK(has(f, n, "UHC:C/lzx") && has(f, n, "UHC:Docs/LZX.guide") && has(f, n, "UHC:Docs/lzx.readme.txt")
          && has(f, n, "UHC:C/unlzx") && has(f, n, "L:LZX.Keyfile"));
    upkg_uhc_files_free(f, n);
    snprintf(p, sizeof p, "%s/amigae", all);
    n = upkg_uhc_files(p, &f, &skipped);
    CHECK(skipped >= 2);                                   /* the ALL / wildcard copies name no single file */
    upkg_uhc_files_free(f, n);

    /* ALL copies a whole drawer: its files are unknown, so it is counted as skipped, never named */
    {
        char sp[1100];
        FILE *fp;
        snprintf(sp, sizeof sp, "%s/allonly", argv[2]);
        fp = fopen(sp, "w");
        fputs("Copy >NIL: somedir \"UHC:Docs/\" ALL\nCopy >NIL: one.txt \"UHC:Docs/\"\n", fp);
        fclose(fp);
        n = upkg_uhc_files(sp, &f, &skipped);
        CHECK(n == 1 && skipped == 1 && has(f, n, "UHC:Docs/one.txt"));
        upkg_uhc_files_free(f, n);
        unlink(sp);
    }

    /* unset variable: nothing is named, the package is refused */
    setenv("UPKG_UHC_ENV", "/nonexistent/env/", 1);
    snprintf(p, sizeof p, "%s/unzip", all);
    CHECK(upkg_uhc_files(p, &f, &skipped) == 0 && skipped == 4);
    CHECK(upkg_uhc_files("/nonexistent/script", &f, &skipped) == 0);
    setenv("UPKG_UHC_ENV", env, 1);

    /* --- U5 end to end: uhc:unzip on remove deletes the Copy targets and Installed/unzip --- */
    {
        char drawer[1100], bin[1100], doc[1100];
        snprintf(drawer, sizeof drawer, "%s/Packages", argv[2]); mkdir(drawer, 0700);
        snprintf(p, sizeof p, "%s/Packages/Installed", argv[2]); mkdir(p, 0700);
        snprintf(bin, sizeof bin, "%s/bin", argv[2]); mkdir(bin, 0700);
        snprintf(doc, sizeof doc, "%s/doc", argv[2]); mkdir(doc, 0700);
        snprintf(p, sizeof p, "%s/env/UHC/EXTBIN", argv[2]); snprintf(p2, sizeof p2, "%s/bin/\n", argv[2]); put(p, p2);
        snprintf(p, sizeof p, "%s/env/UHC/EXTDOC", argv[2]); snprintf(p2, sizeof p2, "%s/doc/\n", argv[2]); put(p, p2);
        snprintf(p, sizeof p, "cp %s/unzip %s/unzip", all, drawer); CHECK(system(p) == 0);
        snprintf(p, sizeof p, "%s/bin/UnZip", argv[2]); put(p, "x");
        snprintf(p, sizeof p, "%s/bin/other", argv[2]); put(p, "keep");
        snprintf(p, sizeof p, "%s/doc/README", argv[2]); put(p, "x");
        snprintf(p, sizeof p, "%s/doc/README.AMI", argv[2]); put(p, "x");
        snprintf(p, sizeof p, "%s/doc/unzip.doc", argv[2]); put(p, "x");
        snprintf(p, sizeof p, "%s/Packages/Installed/unzip", argv[2]); put(p, "5.42\n");
        setenv("UPKG_UHC_DIR", drawer, 1);
        args[0] = (char *)"uhc:unzip"; ac = 1;
        rc = upkg_uhc_run_args("remove", &ac, args, &ran);
        CHECK(rc == 0 && ran == 1 && ac == 0);
        snprintf(p, sizeof p, "%s/bin/UnZip", argv[2]); CHECK(access(p, F_OK) != 0);
        snprintf(p, sizeof p, "%s/doc/README.AMI", argv[2]); CHECK(access(p, F_OK) != 0);
        snprintf(p, sizeof p, "%s/Packages/Installed/unzip", argv[2]); CHECK(access(p, F_OK) != 0);
        snprintf(p, sizeof p, "%s/bin/other", argv[2]); CHECK(access(p, F_OK) == 0);       /* only the named files go */
        snprintf(p, sizeof p, "%s/Packages/unzip", argv[2]); CHECK(access(p, F_OK) == 0);  /* the script stays */
        /* refuses when the parse finds nothing: the variables are unset, the Installed record stays */
        snprintf(p, sizeof p, "%s/Packages/Installed/unzip", argv[2]); put(p, "5.42\n");
        setenv("UPKG_UHC_ENV", "/nonexistent/env/", 1);
        args[0] = (char *)"uhc:unzip"; ac = 1;
        rc = upkg_uhc_run_args("remove", &ac, args, &ran);
        CHECK(rc == 20 && ran == 1);
        CHECK(access(p, F_OK) == 0);
        setenv("UPKG_UHC_ENV", env, 1);
    }

    /* --- U4: the command line, the rc, the D3 name choice --- */
    unsetenv("UPKG_UHC_DIR");
    CHECK(upkg_uhc_name("uhc:unzip") && !strcmp(upkg_uhc_name("uhc:unzip"), "unzip"));
    CHECK(upkg_uhc_name("UHC:unzip") != NULL);
    CHECK(upkg_uhc_name("unzip") == NULL);                 /* a bare name is the ipk */
    CHECK(upkg_uhc_name("uhc:") == NULL);
    s = upkg_uhc_target("unzip"); CHECK(!strcmp(s, "uhc:unzip")); free(s);
    s = upkg_uhc_install_line(upkg_uhc_dir(), "unzip"); CHECK(!strcmp(s, "Execute UP-Term:uhc/Packages/unzip")); free(s);
    s = upkg_uhc_script_path("UP-Term:", "x"); CHECK(!strcmp(s, "UP-Term:x")); free(s);
    CHECK(upkg_uhc_rc(0) == 0 && upkg_uhc_rc(20) == 20 && upkg_uhc_rc(5) == 5 && upkg_uhc_rc(-1) == 20);

    /* install: only the uhc: names run, in order, the others stay in argv for opkg */
    x_calls = 0; x_rc = 0;
    args[0] = (char *)"unzip"; args[1] = (char *)"uhc:curl"; args[2] = (char *)"lzx"; ac = 3;
    rc = upkg_uhc_run_args("install", &ac, args, &ran);
    CHECK(rc == 0 && ran == 1 && x_calls == 1 && ac == 2 && !strcmp(args[0], "unzip") && !strcmp(args[1], "lzx"));
    /* the spawned command line is a shell running the Execute line: C:Execute alone only queues the script as the calling CLI's input */
    CHECK(x_n == 3 && !strcmp(x_argv[0], "/bin/sh") && !strcmp(x_argv[1], "-c") && !strcmp(x_argv[2], "Execute UP-Term:uhc/Packages/curl"));
    /* a bare name alone: nothing runs */
    x_calls = 0;
    args[0] = (char *)"unzip"; ac = 1;
    rc = upkg_uhc_run_args("install", &ac, args, &ran);
    CHECK(rc == 0 && ran == 0 && x_calls == 0 && ac == 1);
    /* UHCRC 20 is the exit code; the first failure wins */
    x_rc = 20; x_calls = 0;
    args[0] = (char *)"uhc:unzip"; args[1] = (char *)"uhc:curl"; ac = 2;
    rc = upkg_uhc_run_args("upgrade", &ac, args, &ran);
    CHECK(rc == 20 && ran == 2 && ac == 0 && x_calls == 2);
    x_rc = -1;
    args[0] = (char *)"uhc:unzip"; ac = 1;
    rc = upkg_uhc_run_args("install", &ac, args, &ran);
    CHECK(rc == 20);

    if (fails) return 1;
    printf("[OK] uhc_run: %lu of %lu shipped scripts parse to files, Execute line and UHCRC mapping, uhc: name choice, remove end to end\n",
           (unsigned long)parsed, (unsigned long)scripts);
    return 0;
}
