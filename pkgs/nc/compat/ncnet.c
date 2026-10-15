/* What ixemul's netdb.h declares and its library lacks, IPv4 only (the stack
 * here has no IPv6): getaddrinfo, freeaddrinfo, gai_strerror, getnameinfo, plus
 * strlcpy and asprintf. Built on gethostbyname, inet_aton, getservbyname. */
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

size_t
strlcpy(char *dst, const char *src, size_t size)
{
	size_t n = strlen(src);

	if (size) {
		size_t c = n >= size ? size - 1 : n;
		memcpy(dst, src, c);
		dst[c] = '\0';
	}
	return n;
}

int
asprintf(char **out, const char *fmt, ...)
{
	va_list ap;
	int n;
	char *p;

	va_start(ap, fmt);
	n = vsnprintf(NULL, 0, fmt, ap);
	va_end(ap);
	if (n < 0 || (p = malloc((size_t)n + 1)) == NULL) {
		*out = NULL;
		return -1;
	}
	va_start(ap, fmt);
	vsnprintf(p, (size_t)n + 1, fmt, ap);
	va_end(ap);
	*out = p;
	return n;
}

static const char *const gai_msgs[] = {
	"Success", "Address family for hostname not supported",
	"Temporary failure in name resolution", "Invalid value for ai_flags",
	"Non-recoverable failure in name resolution",
	"ai_family not supported", "Memory allocation failure",
	"No address associated with hostname",
	"hostname nor servname provided, or not known",
	"servname not supported for ai_socktype", "ai_socktype not supported",
	"System error", "Invalid value for hints", "Resolved protocol is unknown",
	"Argument buffer overflow"
};

char *
gai_strerror(int e)
{
	if (e < 0 || e > EAI_MAX)
		return (char *)"Unknown error";
	return (char *)gai_msgs[e];
}

void
freeaddrinfo(struct addrinfo *ai)
{
	while (ai) {
		struct addrinfo *n = ai->ai_next;
		free(ai->ai_addr);
		free(ai->ai_canonname);
		free(ai);
		ai = n;
	}
}

static struct addrinfo *
mk(const struct addrinfo *h, int socktype, int proto, struct in_addr a, int port,
    const char *canon)
{
	struct addrinfo *ai = calloc(1, sizeof *ai);
	struct sockaddr_in *sin = calloc(1, sizeof *sin);

	if (!ai || !sin) {
		free(ai);
		free(sin);
		return NULL;
	}
	sin->sin_len = sizeof *sin;
	sin->sin_family = AF_INET;
	sin->sin_port = htons((unsigned short)port);
	sin->sin_addr = a;
	ai->ai_flags = h ? h->ai_flags : 0;
	ai->ai_family = AF_INET;
	ai->ai_socktype = socktype;
	ai->ai_protocol = proto;
	ai->ai_addrlen = sizeof *sin;
	ai->ai_addr = (struct sockaddr *)sin;
	if (canon && h && (h->ai_flags & AI_CANONNAME))
		ai->ai_canonname = strdup(canon);
	return ai;
}

int
getaddrinfo(const char *host, const char *serv, const struct addrinfo *hints,
    struct addrinfo **res)
{
	int family = hints ? hints->ai_family : AF_UNSPEC;
	int flags = hints ? hints->ai_flags : 0;
	int st = hints ? hints->ai_socktype : 0;
	struct { int type, proto; const char *name; } kinds[2];
	int nk = 0, i, j, port = 0, na = 0;
	struct in_addr addrs[16];
	const char *canon = NULL;
	struct addrinfo *head = NULL, **tail = &head;

	if (!host && !serv)
		return EAI_NONAME;
	if (family != AF_UNSPEC && family != AF_INET)
		return EAI_FAMILY;
	if (st == 0 || st == SOCK_STREAM) {
		kinds[nk].type = SOCK_STREAM; kinds[nk].proto = IPPROTO_TCP;
		kinds[nk++].name = "tcp";
	}
	if (st == 0 || st == SOCK_DGRAM) {
		kinds[nk].type = SOCK_DGRAM; kinds[nk].proto = IPPROTO_UDP;
		kinds[nk++].name = "udp";
	}
	if (nk == 0)
		return EAI_SOCKTYPE;

	if (serv) {
		char *end;
		long n = strtol(serv, &end, 10);
		if (*serv && !*end && n >= 0 && n < 65536) {
			port = (int)n;
		} else if (flags & AI_NUMERICSERV) {
			return EAI_NONAME;
		} else {
			struct servent *se = getservbyname(serv, kinds[0].name);
			if (!se)
				return EAI_SERVICE;
			port = ntohs((unsigned short)se->s_port);
		}
	}

	if (!host) {
		addrs[0].s_addr = htonl((flags & AI_PASSIVE) ? INADDR_ANY : INADDR_LOOPBACK);
		na = 1;
	} else if (inet_aton(host, &addrs[0])) {
		na = 1;
	} else if (flags & AI_NUMERICHOST) {
		return EAI_NONAME;
	} else {
		struct hostent *he = gethostbyname(host);
		if (!he || he->h_addrtype != AF_INET || !he->h_addr_list[0])
			return h_errno == TRY_AGAIN ? EAI_AGAIN : EAI_NONAME;
		for (; he->h_addr_list[na] && na < 16; na++)
			memcpy(&addrs[na], he->h_addr_list[na], sizeof(struct in_addr));
		canon = he->h_name;
	}

	for (i = 0; i < na; i++)
		for (j = 0; j < nk; j++) {
			struct addrinfo *ai = mk(hints, kinds[j].type, kinds[j].proto,
			    addrs[i], port, canon ? canon : host);
			if (!ai) {
				freeaddrinfo(head);
				return EAI_MEMORY;
			}
			*tail = ai;
			tail = &ai->ai_next;
		}
	*res = head;
	return 0;
}

int
getnameinfo(const struct sockaddr *sa, socklen_t salen, char *host,
    socklen_t hostlen, char *serv, socklen_t servlen, int flags)
{
	const struct sockaddr_in *sin = (const struct sockaddr_in *)sa;
	(void)flags;

	if (sa->sa_family != AF_INET || salen < sizeof *sin)
		return EAI_FAMILY;
	if (host && hostlen) {
		const char *s = inet_ntoa(sin->sin_addr);
		if (strlen(s) >= hostlen)
			return EAI_OVERFLOW;
		strcpy(host, s);
	}
	if (serv && servlen) {
		char b[8];
		snprintf(b, sizeof b, "%u", ntohs(sin->sin_port));
		if (strlen(b) >= servlen)
			return EAI_OVERFLOW;
		strcpy(serv, b);
	}
	return 0;
}
