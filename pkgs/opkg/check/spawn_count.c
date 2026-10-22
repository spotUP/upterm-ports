/* spawn_count.c: preload shim for check/browse_tty.sh. Every fork, vfork, posix_spawn, execve and system call
 * of the program adds one byte to the file named by SPAWN_COUNT_FILE. The shim lives outside the program so the
 * program under test carries no test hook. macOS: DYLD_INSERT_LIBRARIES with __interpose; Linux: LD_PRELOAD. */
#define _GNU_SOURCE
#include <fcntl.h>
#include <spawn.h>
#include <stdlib.h>
#include <unistd.h>

static void count(void)
{
    const char *f = getenv("SPAWN_COUNT_FILE");
    int fd;

    if (!f)
        return;
    fd = open(f, O_WRONLY | O_APPEND | O_CREAT, 0644);
    if (fd >= 0) {
        (void) !write(fd, "x", 1);
        close(fd);
    }
}

#ifdef __APPLE__
static pid_t my_fork(void) { count(); return fork(); }
static int my_system(const char *c) { count(); return system(c); }
static int my_execve(const char *p, char *const a[], char *const e[]) { count(); return execve(p, a, e); }
static int my_spawn(pid_t *pid, const char *p, const posix_spawn_file_actions_t *fa, const posix_spawnattr_t *at,
                    char *const a[], char *const e[]) { count(); return posix_spawn(pid, p, fa, at, a, e); }
#define INTERPOSE(n, o) __attribute__((used)) static struct { const void *r; const void *o_; } \
    interpose_##o __attribute__((section("__DATA,__interpose"))) = { (const void *) (n), (const void *) (o) }
INTERPOSE(my_fork, fork);
INTERPOSE(my_system, system);
INTERPOSE(my_execve, execve);
INTERPOSE(my_spawn, posix_spawn);
#else
#include <dlfcn.h>
pid_t fork(void) { pid_t (*r)(void) = dlsym(RTLD_NEXT, "fork"); count(); return r(); }
pid_t vfork(void) { count(); return fork(); }
int system(const char *c) { int (*r)(const char *) = dlsym(RTLD_NEXT, "system"); count(); return r(c); }
int execve(const char *p, char *const a[], char *const e[])
{ int (*r)(const char *, char *const[], char *const[]) = dlsym(RTLD_NEXT, "execve"); count(); return r(p, a, e); }
int posix_spawn(pid_t *pid, const char *p, const posix_spawn_file_actions_t *fa, const posix_spawnattr_t *at,
                char *const a[], char *const e[])
{ int (*r)(pid_t *, const char *, const posix_spawn_file_actions_t *, const posix_spawnattr_t *, char *const[], char *const[])
      = dlsym(RTLD_NEXT, "posix_spawn"); count(); return r(pid, p, fa, at, a, e); }
#endif
