/* wrap_split.c: driver for check/wrap_split.sh. Prints one word in two calls and a second
 * one in two stream-split pieces, so the writer must hold the partial word across calls. */
#include <stdio.h>
#include "upkg_wrap.h"

int main(void)
{
    upkg_printf("aaaa bbbb cccc dddd eeee ffff gggg abc");
    upkg_printf("def and the rest\n");
    upkg_printf("aaaa bbbb cccc dddd eeee ffff gggg ab");
    upkg_printf("c");
    upkg_printf("d");
    upkg_printf("ef"); /* ends at exit with no newline: the atexit flush writes it */
    return 0;
}
