/* The OpenBSD libc calls netcat.c and socks.c use that ixemul does not have. */
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

/* -r picks random ports; not a cryptographic use, so rand() seeded once */
unsigned int
arc4random_uniform(unsigned int upper)
{
	static int seeded;
	unsigned int min, r;

	if (!seeded) {
		srand((unsigned int)time(NULL) ^ ((unsigned int)getpid() << 8));
		seeded = 1;
	}
	if (upper < 2)
		return 0;
	min = -upper % upper;
	do {
		r = ((unsigned int)rand() << 16) ^ (unsigned int)rand();
	} while (r < min);
	return r % upper;
}

void
explicit_bzero(void *p, size_t n)
{
	volatile unsigned char *q = p;

	while (n--)
		*q++ = 0;
}

int
b64_ntop(const unsigned char *src, size_t srclen, char *target, size_t targsize)
{
	static const char tab[] =
	    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
	size_t need = (srclen + 2) / 3 * 4, o = 0;

	if (need + 1 > targsize)
		return -1;
	while (srclen >= 3) {
		target[o++] = tab[src[0] >> 2];
		target[o++] = tab[((src[0] & 3) << 4) | (src[1] >> 4)];
		target[o++] = tab[((src[1] & 15) << 2) | (src[2] >> 6)];
		target[o++] = tab[src[2] & 63];
		src += 3;
		srclen -= 3;
	}
	if (srclen) {
		target[o++] = tab[src[0] >> 2];
		if (srclen == 1) {
			target[o++] = tab[(src[0] & 3) << 4];
			target[o++] = '=';
		} else {
			target[o++] = tab[((src[0] & 3) << 4) | (src[1] >> 4)];
			target[o++] = tab[(src[1] & 15) << 2];
		}
		target[o++] = '=';
	}
	target[o] = '\0';
	return (int)o;
}
