/* Force-included before netcat.c (-include): what OpenBSD's netcat.c uses and
 * ixemul does not declare. IPv6 and routing tables do not exist on this network
 * stack, so the constants only let the code compile; getaddrinfo never returns
 * AF_INET6 and the -V option fails at run time (setrtable below). */
#ifndef NC_AMIGA_H
#define NC_AMIGA_H
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <sys/filio.h>
#include <stdint.h>
#include <errno.h>

typedef u_int32_t n_time;

#ifndef AF_INET6
#define AF_INET6 24
#endif
#ifndef IPPROTO_IPV6
#define IPPROTO_IPV6 41
#define IPV6_TCLASS 61
#define IPV6_UNICAST_HOPS 4
#define IPV6_MINHOPCOUNT 73
#endif
#define RT_TABLEID_MAX 255
#define SO_BINDANY 0
#define TCP_MD5SIG 4

/* accept4 and the socket type flags: ixnet's socket and accept take none */
#define SOCK_NONBLOCK 0x20000000
#define SOCK_CLOEXEC  0x10000000

static inline int nc_flags(int fd, int flags)
{
	int on = 1;
	if (fd >= 0 && (flags & SOCK_NONBLOCK))
		ioctl(fd, FIONBIO, &on);
	return fd;
}
static inline int nc_socket(int d, int t, int p)
{
	return nc_flags(socket(d, t & ~(SOCK_NONBLOCK | SOCK_CLOEXEC), p),
	    t);
}
static inline int nc_accept4(int s, struct sockaddr *a, socklen_t *l, int flags)
{
	return nc_flags(accept(s, a, l), flags);
}
#define socket nc_socket
#define accept4 nc_accept4

static inline int setrtable(int id) { (void)id; errno = ENOSYS; return -1; }

#ifndef strtonum
long long strtonum(const char *, long long, long long, const char **);
#endif

/* netinet/ip.h and friends here lack these */
typedef u_int16_t in_port_t;
struct sockaddr_in6 { u_int8_t sin6_len; u_int8_t sin6_family; u_int16_t sin6_port;
	u_int32_t sin6_flowinfo; u_int8_t sin6_addr[16]; u_int32_t sin6_scope_id; };
#define IP_MINTTL 32
#define IPTOS_DSCP_AF11 0x28
#define IPTOS_DSCP_AF12 0x30
#define IPTOS_DSCP_AF13 0x38
#define IPTOS_DSCP_AF21 0x48
#define IPTOS_DSCP_AF22 0x50
#define IPTOS_DSCP_AF23 0x58
#define IPTOS_DSCP_AF31 0x68
#define IPTOS_DSCP_AF32 0x70
#define IPTOS_DSCP_AF33 0x78
#define IPTOS_DSCP_AF41 0x88
#define IPTOS_DSCP_AF42 0x90
#define IPTOS_DSCP_AF43 0x98
#define IPTOS_DSCP_CS0 0x00
#define IPTOS_DSCP_CS1 0x20
#define IPTOS_DSCP_CS2 0x40
#define IPTOS_DSCP_CS3 0x60
#define IPTOS_DSCP_CS4 0x80
#define IPTOS_DSCP_CS5 0xa0
#define IPTOS_DSCP_CS6 0xc0
#define IPTOS_DSCP_CS7 0xe0
#define IPTOS_DSCP_EF 0xb8
#define IPTOS_DSCP_VA 0xb0
#define IPTOS_PREC_CRITIC_ECP 0xa0
#define IPTOS_PREC_INTERNETCONTROL 0xc0
#define IPTOS_PREC_NETCONTROL 0xe0

#include <stddef.h>
size_t strlcpy(char *, const char *, size_t);
unsigned int arc4random_uniform(unsigned int);
void explicit_bzero(void *, size_t);
int b64_ntop(const unsigned char *, size_t, char *, size_t);
#endif
