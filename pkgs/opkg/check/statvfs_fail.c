/* statvfs_fail.c: preload shim for check/statvfs_root.sh. statvfs of exactly the path named by
 * STATVFS_FAIL fails with EPERM, as ixemul's statfs does for "/" from a plain AmigaDOS Shell.
 * macOS: DYLD_INSERT_LIBRARIES with __interpose; elsewhere LD_PRELOAD with dlsym(RTLD_NEXT). */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <sys/statvfs.h>

#ifdef __APPLE__
#define SHIM shim_statvfs
#else
#define SHIM statvfs
#endif

int SHIM(const char *path, struct statvfs *buf)
{
    const char *bad = getenv("STATVFS_FAIL");

    if (bad != NULL && path != NULL && strcmp(path, bad) == 0) {
        errno = EPERM;
        return -1;
    }
#ifdef __APPLE__
    return statvfs(path, buf);
#else
    static int (*real)(const char *, struct statvfs *);
    if (!real)
        real = (int (*)(const char *, struct statvfs *))dlsym(RTLD_NEXT, "statvfs");
    return real(path, buf);
#endif
}
#ifdef __APPLE__
__attribute__((used)) static struct { const void *n, *o; } interpose_statvfs
    __attribute__((section("__DATA,__interpose"))) = { (const void *)SHIM, (const void *)statvfs };
#endif
