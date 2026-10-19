/* ffs_names.c: preload shim for check/temp_name.sh. Under the directory named by FFS_ROOT,
 * mkstemp, mkdtemp, mkdir and open(O_CREAT) refuse a new name whose last component has more
 * than 30 characters with ENAMETOOLONG, as ixemul does on AmigaDOS FFS. Names outside FFS_ROOT
 * (the host's own temp paths) pass through. macOS: DYLD_INSERT_LIBRARIES with __interpose;
 * elsewhere: LD_PRELOAD with dlsym(RTLD_NEXT). */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#define FFS_NAME_MAX 30

static int too_long(const char *path)
{
    const char *root = getenv("FFS_ROOT"), *last;
    size_t n;

    if (root == NULL || path == NULL)
        return 0;
    n = strlen(root);
    if (strncmp(path, root, n) != 0 || (path[n] != '/' && path[n] != '\0'))
        return 0;
    last = strrchr(path, '/');
    last = last ? last + 1 : path;
    if (strlen(last) <= FFS_NAME_MAX)
        return 0;
    errno = ENAMETOOLONG;
    return 1;
}

#ifdef __APPLE__
#define REAL(name) name
#define SHIM(name) shim_##name
#else
#define REAL(name) real_##name
#define SHIM(name) name
#define NEXT(name) static __typeof__(name) *REAL(name); \
    if (!REAL(name)) REAL(name) = (__typeof__(name) *)dlsym(RTLD_NEXT, #name)
#endif

int SHIM(mkstemp)(char *tmpl)
{
#ifndef __APPLE__
    NEXT(mkstemp);
#endif
    return too_long(tmpl) ? -1 : REAL(mkstemp)(tmpl);
}

char *SHIM(mkdtemp)(char *tmpl)
{
#ifndef __APPLE__
    NEXT(mkdtemp);
#endif
    return too_long(tmpl) ? NULL : REAL(mkdtemp)(tmpl);
}

int SHIM(mkdir)(const char *path, mode_t mode)
{
#ifndef __APPLE__
    NEXT(mkdir);
#endif
    return too_long(path) ? -1 : REAL(mkdir)(path, mode);
}

int SHIM(open)(const char *path, int flags, ...)
{
    mode_t mode = 0;
#ifndef __APPLE__
    NEXT(open);
#endif
    if (flags & O_CREAT) {
        va_list ap;
        va_start(ap, flags);
        mode = (mode_t)va_arg(ap, int);
        va_end(ap);
        if (too_long(path))
            return -1;
    }
    return REAL(open)(path, flags, mode);
}

#ifdef __APPLE__
#define INTERPOSE(name) __attribute__((used)) static const struct { const void *shim, *real; } \
    interpose_##name __attribute__((section("__DATA,__interpose"))) = { (const void *)SHIM(name), (const void *)REAL(name) }
INTERPOSE(mkstemp);
INTERPOSE(mkdtemp);
INTERPOSE(mkdir);
INTERPOSE(open);
#endif
