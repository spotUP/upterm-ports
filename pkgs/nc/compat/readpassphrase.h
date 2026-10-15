/* readpassphrase for socks.c (-X connect with a proxy password): no echo
 * control exists on the console handler, so the prompt reads one visible line. */
#ifndef NC_READPASSPHRASE_H
#define NC_READPASSPHRASE_H
#include <stdio.h>
#include <string.h>
#define RPP_ECHO_OFF 0
#define RPP_REQUIRE_TTY 0
static inline char *readpassphrase(const char *prompt, char *buf, size_t len, int flags)
{
	size_t n;
	(void)flags;
	fputs(prompt, stderr);
	fflush(stderr);
	if (fgets(buf, (int)len, stdin) == NULL)
		return NULL;
	n = strlen(buf);
	if (n > 0 && buf[n - 1] == '\n')
		buf[n - 1] = '\0';
	return buf;
}
#endif
