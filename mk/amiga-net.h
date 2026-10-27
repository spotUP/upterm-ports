/* Forced into every curl compile and configure probe (recipe.mk CPPFLAGS).
 * The NDK netinclude (netinet/in.h) spells its 32-bit type __uint32_t, which
 * newlib's sys/types.h defines and ixemul's does not. */
#include <sys/types.h>
#ifndef __uint32_t
typedef u_int32_t __uint32_t;
#define __uint32_t __uint32_t
#endif
