/* libtls is not part of the Amiga userland: nc is built without TLS. These
 * declarations let OpenBSD's netcat.c compile unchanged; tls_stub.c answers
 * every call that could start a TLS session with an error. */
#ifndef NC_TLS_H
#define NC_TLS_H
#include <sys/types.h>
#include <stdint.h>
#include <time.h>
struct tls;
struct tls_config;
#define TLS_WANT_POLLIN  (-2)
#define TLS_WANT_POLLOUT (-3)
#define TLS_OCSP_RESPONSE_SUCCESSFUL 1
const char *tls_default_ca_cert_file(void);
struct tls_config *tls_config_new(void);
void tls_config_free(struct tls_config *);
const char *tls_config_error(struct tls_config *);
int tls_config_set_ca_file(struct tls_config *, const char *);
int tls_config_set_cert_file(struct tls_config *, const char *);
int tls_config_set_key_file(struct tls_config *, const char *);
int tls_config_set_ocsp_staple_file(struct tls_config *, const char *);
int tls_config_parse_protocols(uint32_t *, const char *);
int tls_config_set_protocols(struct tls_config *, uint32_t);
int tls_config_set_ciphers(struct tls_config *, const char *);
int tls_config_set_alpn(struct tls_config *, const char *);
void tls_config_insecure_noverifyname(struct tls_config *);
void tls_config_insecure_noverifycert(struct tls_config *);
void tls_config_ocsp_require_stapling(struct tls_config *);
void tls_config_verify_client_optional(struct tls_config *);
struct tls *tls_server(void);
struct tls *tls_client(void);
int tls_configure(struct tls *, struct tls_config *);
const char *tls_error(struct tls *);
int tls_close(struct tls *);
void tls_free(struct tls *);
int tls_handshake(struct tls *);
int tls_connect_socket(struct tls *, int, const char *);
int tls_accept_socket(struct tls *, struct tls **, int);
ssize_t tls_read(struct tls *, void *, size_t);
ssize_t tls_write(struct tls *, const void *, size_t);
int tls_peer_cert_provided(struct tls *);
const char *tls_peer_cert_hash(struct tls *);
int tls_peer_cert_contains_name(struct tls *, const char *);
const char *tls_peer_cert_subject(struct tls *);
const char *tls_peer_cert_issuer(struct tls *);
time_t tls_peer_cert_notbefore(struct tls *);
time_t tls_peer_cert_notafter(struct tls *);
const char *tls_peer_cert_unverified_bundle_pem(struct tls *, size_t *);
const char *tls_peer_ocsp_url(struct tls *);
int tls_peer_ocsp_response_status(struct tls *);
int tls_peer_ocsp_cert_status(struct tls *);
int tls_peer_ocsp_crl_reason(struct tls *);
const char *tls_peer_ocsp_result(struct tls *);
time_t tls_peer_ocsp_this_update(struct tls *);
time_t tls_peer_ocsp_next_update(struct tls *);
time_t tls_peer_ocsp_revocation_time(struct tls *);
const char *tls_conn_version(struct tls *);
const char *tls_conn_cipher(struct tls *);
const char *tls_conn_alpn_selected(struct tls *);
#endif
