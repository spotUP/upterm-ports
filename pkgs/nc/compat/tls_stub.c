/* nc without TLS (see tls.h). Starting a session fails with one clear message;
 * the other entry points are never reached once tls_config_new has exited. */
#include <err.h>
#include <stddef.h>
#include "tls.h"

#define NOTLS "TLS is not built into this nc (option -c)"

const char *tls_default_ca_cert_file(void) { return NULL; }
struct tls_config *tls_config_new(void) { errx(1, NOTLS); return NULL; }
void tls_config_free(struct tls_config *c) { (void)c; }
const char *tls_config_error(struct tls_config *c) { (void)c; return NOTLS; }
int tls_config_set_ca_file(struct tls_config *c, const char *s) { (void)c; (void)s; return -1; }
int tls_config_set_cert_file(struct tls_config *c, const char *s) { (void)c; (void)s; return -1; }
int tls_config_set_key_file(struct tls_config *c, const char *s) { (void)c; (void)s; return -1; }
int tls_config_set_ocsp_staple_file(struct tls_config *c, const char *s) { (void)c; (void)s; return -1; }
int tls_config_parse_protocols(uint32_t *p, const char *s) { (void)p; (void)s; return -1; }
int tls_config_set_protocols(struct tls_config *c, uint32_t p) { (void)c; (void)p; return -1; }
int tls_config_set_ciphers(struct tls_config *c, const char *s) { (void)c; (void)s; return -1; }
int tls_config_set_alpn(struct tls_config *c, const char *s) { (void)c; (void)s; return -1; }
void tls_config_insecure_noverifyname(struct tls_config *c) { (void)c; }
void tls_config_insecure_noverifycert(struct tls_config *c) { (void)c; }
void tls_config_ocsp_require_stapling(struct tls_config *c) { (void)c; }
void tls_config_verify_client_optional(struct tls_config *c) { (void)c; }
struct tls *tls_server(void) { return NULL; }
struct tls *tls_client(void) { return NULL; }
int tls_configure(struct tls *t, struct tls_config *c) { (void)t; (void)c; return -1; }
const char *tls_error(struct tls *t) { (void)t; return NOTLS; }
int tls_close(struct tls *t) { (void)t; return 0; }
void tls_free(struct tls *t) { (void)t; }
int tls_handshake(struct tls *t) { (void)t; return -1; }
int tls_connect_socket(struct tls *t, int s, const char *n) { (void)t; (void)s; (void)n; return -1; }
int tls_accept_socket(struct tls *t, struct tls **o, int s) { (void)t; (void)o; (void)s; return -1; }
ssize_t tls_read(struct tls *t, void *b, size_t n) { (void)t; (void)b; (void)n; return -1; }
ssize_t tls_write(struct tls *t, const void *b, size_t n) { (void)t; (void)b; (void)n; return -1; }
int tls_peer_cert_provided(struct tls *t) { (void)t; return 0; }
const char *tls_peer_cert_hash(struct tls *t) { (void)t; return NULL; }
int tls_peer_cert_contains_name(struct tls *t, const char *n) { (void)t; (void)n; return 0; }
const char *tls_peer_cert_subject(struct tls *t) { (void)t; return NULL; }
const char *tls_peer_cert_issuer(struct tls *t) { (void)t; return NULL; }
time_t tls_peer_cert_notbefore(struct tls *t) { (void)t; return -1; }
time_t tls_peer_cert_notafter(struct tls *t) { (void)t; return -1; }
const char *tls_peer_cert_unverified_bundle_pem(struct tls *t, size_t *n) { (void)t; (void)n; return NULL; }
const char *tls_peer_ocsp_url(struct tls *t) { (void)t; return NULL; }
int tls_peer_ocsp_response_status(struct tls *t) { (void)t; return 0; }
int tls_peer_ocsp_cert_status(struct tls *t) { (void)t; return 0; }
int tls_peer_ocsp_crl_reason(struct tls *t) { (void)t; return 0; }
const char *tls_peer_ocsp_result(struct tls *t) { (void)t; return NULL; }
time_t tls_peer_ocsp_this_update(struct tls *t) { (void)t; return -1; }
time_t tls_peer_ocsp_next_update(struct tls *t) { (void)t; return -1; }
time_t tls_peer_ocsp_revocation_time(struct tls *t) { (void)t; return -1; }
const char *tls_conn_version(struct tls *t) { (void)t; return NULL; }
const char *tls_conn_cipher(struct tls *t) { (void)t; return NULL; }
const char *tls_conn_alpn_selected(struct tls *t) { (void)t; return NULL; }
