/* Forced into every curl compile and configure probe (recipe.mk CPPFLAGS).
 * The NDK netinclude (netinet/in.h) spells its 32-bit type __uint32_t, which
 * newlib's sys/types.h defines and ixemul's does not. */
#include <sys/types.h>
#ifndef __uint32_t
typedef u_int32_t __uint32_t;
#define __uint32_t __uint32_t
#endif
/* NDK <sys/socket.h> pulls in <devices/timer.h>, which defines its own struct
 * timeval and meets ixemul's <sys/time.h> ("redefinition of struct timeval", which
 * made configure's fcntl.h probe fail). Its _TIMEVAL_DEFINED guard makes it use
 * ixemul's (included first here, so it exists), whose layout (two longs) equals the Amiga one. */
#include <sys/time.h>
#ifndef _TIMEVAL_DEFINED
#define _TIMEVAL_DEFINED
#endif
