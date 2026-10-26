/* wb_exec.c UPKG: exec PROGRAM with argc == 0, the way Workbench starts a program from an icon
 * (argv is then a struct WBStartup, never a command line). A shell cannot pass an empty argv.
 *   wb_exec PROGRAM */
#include <stdio.h>
#include <unistd.h>

extern char **environ;

int main(int argc, char **argv)
{
    char *empty[] = { NULL };

    if (argc != 2) {
        fprintf(stderr, "usage: wb_exec PROGRAM\n");
        return 2;
    }
    execve(argv[1], empty, environ);
    perror("wb_exec");
    return 127;
}
