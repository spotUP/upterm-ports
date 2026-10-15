/* Host (macOS) build only: the OpenBSD names netcat.c uses that macOS lacks. Not used for the Amiga build (amiga_nc.h). */
#include <sys/types.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <stdint.h>
#include <netinet/in.h>
#include <netinet/ip.h>
#include <netinet/tcp.h>
#define pledge(a,b) 0
#define unveil(a,b) 0
static inline void *reallocarray(void *p, size_t n, size_t s){ if (s && n > (size_t)-1/s){errno=ENOMEM;return 0;} return realloc(p,n*s);} 
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <fcntl.h>
#include <unistd.h>
#define RT_TABLEID_MAX 255
#define SO_BINDANY 0
#define TCP_MD5SIG 4
#define SOCK_NONBLOCK 0x20000000
#define SOCK_CLOEXEC 0x10000000
static inline int nc_flags(int fd,int f){ if(fd>=0&&(f&SOCK_NONBLOCK)) fcntl(fd,F_SETFL,fcntl(fd,F_GETFL)|O_NONBLOCK); return fd;}
static inline int nc_socket(int d,int t,int p){return nc_flags(socket(d,t&~(SOCK_NONBLOCK|SOCK_CLOEXEC),p),t);}
static inline int nc_accept4(int s,struct sockaddr*a,socklen_t*l,int f){return nc_flags(accept(s,a,l),f);}
#define socket nc_socket
#define accept4 nc_accept4
static inline int setrtable(int id){(void)id;errno=ENOSYS;return -1;}
#ifndef IP_MINTTL
#define IP_MINTTL 24
#endif
#ifndef IPV6_MINHOPCOUNT
#define IPV6_MINHOPCOUNT 73
#endif
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
#define explicit_bzero(p,n) memset_s(p,n,0,n)
