/* dirname_self.c: preload shim for check/mkdir_absent_root.sh. dirname of a path that ends in ':' with no
 * '/' (an Amiga volume root such as NOSUCHVOL: or NOSUCHVOL:dir) returns the volume root itself, as the
 * Amiga libc does for the root: host dirname("NOSUCHVOL:") is "." and would never loop. Any other path goes
 * to the real dirname. macOS: DYLD_INSERT_LIBRARIES with __interpose; elsewhere LD_PRELOAD. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <libgen.h>
#include <string.h>

#ifdef __APPLE__
#define SHIM shim_dirname
#else
#define SHIM dirname
#endif

char *SHIM(char *path)
{
    char *colon = path ? strchr(path, ':') : NULL;

    if (colon != NULL && strchr(path, '/') == NULL) {
        colon[1] = '\0';
        return path;
    }
#ifdef __APPLE__
    return dirname(path);
#else
    static char *(*real)(char *);
    if (!real)
        real = (char *(*)(char *))dlsym(RTLD_NEXT, "dirname");
    return real(path);
#endif
}
#ifdef __APPLE__
__attribute__((used)) static struct { const void *n, *o; } interpose_dirname
    __attribute__((section("__DATA,__interpose"))) = { (const void *)SHIM, (const void *)dirname };
#endif
