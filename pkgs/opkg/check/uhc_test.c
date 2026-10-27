/* uhc_test.c: unit test of libopkg/upkg_uhc.c (patch 0042), built by check/uhc.sh. Reads the fixture drawer
 * check/uhc/Packages (unzip, curl, lzx copied from the up-uhc archive; Installed/ holds unzip 5.40 and curl 7.10.5)
 * plus a scratch drawer for the odd cases. Exit 0 and one [OK] line on success. */
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

static int fails;
#define CHECK(c) do { if (!(c)) { fprintf(stderr, "[FAIL] uhc: line %d: %s\n", __LINE__, #c); fails++; } } while (0)

static void put(const char *dir, const char *name, const char *text)
{
    char p[1024];
    FILE *fp;

    snprintf(p, sizeof p, "%s/%s", dir, name);
    fp = fopen(p, "w");
    if (!fp) { perror(p); exit(2); }
    fputs(text, fp);
    fclose(fp);
}

int main(int argc, char **argv)
{
    upkg_uhc_t u = { 0 };
    char odd[1024], sub[1100];

    if (argc != 3) { fprintf(stderr, "usage: uhc_test FIXTURE_DRAWER SCRATCH_DIR\n"); return 2; }

    /* the constant is the default; the environment overrides it */
    unsetenv("UPKG_UHC_DIR");
    CHECK(!strcmp(upkg_uhc_dir(), UPKG_UHC_DIR_DEFAULT));
    setenv("UPKG_UHC_DIR", argv[1], 1);
    CHECK(!strcmp(upkg_uhc_dir(), argv[1]));

    /* the real archive scripts: three packages, sorted, .desc files and Installed/ are not entries */
    CHECK(upkg_uhc_read(&u, upkg_uhc_dir()) == 3);
    CHECK(u.n == 3 && !strcmp(u.pkg[0].name, "curl") && !strcmp(u.pkg[1].name, "lzx") && !strcmp(u.pkg[2].name, "unzip"));
    CHECK(!strcmp(u.pkg[0].version, "7.10.5") && !strcmp(u.pkg[1].version, "1.21r") && !strcmp(u.pkg[2].version, "5.42"));
    CHECK(!strcmp(u.pkg[2].desc, "Extractor for zip-archives"));
    CHECK(!strcmp(u.pkg[0].installed, "7.10.5"));    /* current */
    CHECK(!strcmp(u.pkg[1].installed, ""));          /* not installed */
    CHECK(!strcmp(u.pkg[2].installed, "5.40"));      /* older than the script's 5.42 */

    /* odd drawers */
    snprintf(odd, sizeof odd, "%s/odd", argv[2]);
    mkdir(argv[2], 0700);
    mkdir(odd, 0700);
    snprintf(sub, sizeof sub, "%s/Installed", odd);
    mkdir(sub, 0700);
    put(odd, "bare", "Set PKGNAME \"bare\"\nset pkgversion 2.0 \nEcho \"${PKGVERSION}\"\n");   /* no quotes, any case */
    put(odd, "bare.desc", "  Bare package   \n second line ignored\n");
    put(odd, "noversion", "Set PKGNAME \"x\"\nEcho \"Set PKGVERSION 9\"\n");                  /* not a Set line */
    put(odd, ".hidden", "Set PKGVERSION \"1\"\n");
    put(odd, "Installed/ghost", "1.0\n");                                                      /* record without a script */
    put(odd, "bare.desc.bak", "Set PKGVERSION \"3\"\n");                                       /* only ".desc" is skipped as a suffix */
    CHECK(upkg_uhc_read(&u, odd) == 2);
    CHECK(!strcmp(u.pkg[0].name, "bare") && !strcmp(u.pkg[0].version, "2.0") && !strcmp(u.pkg[0].desc, "Bare package"));
    CHECK(!strcmp(u.pkg[1].name, "bare.desc.bak") && !strcmp(u.pkg[1].version, "3"));

    /* a missing drawer is an empty catalogue; reading again replaces the old entries */
    CHECK(upkg_uhc_read(&u, "/nonexistent/uhc/drawer") == 0 && u.n == 0 && u.pkg == NULL);
    upkg_uhc_free(&u);

    if (fails) return 1;
    printf("[OK] uhc: fixture drawer read (3 packages, versions, descs, installed records); odd drawer cases\n");
    return 0;
}
