/* Reduced repro: m68k-amigaos-gcc 6.5.0b, -m68020 -O1/-O2/-Os. The 16-byte copy of a
   to the stack uses (a2)+; CSE1 (and gcse cprop) then reuse the post-incremented a2
   as the struct-return pointer a0 for app(), so app writes its result into b. */
typedef struct { unsigned char kind, pad; unsigned short off; int size; union { void *ptr; double n; } u; } jv;
jv app(jv s, const char *d, unsigned len);
const char *val(jv s);
unsigned len_of(jv s);
void jfree(jv s);
jv concat(jv a, jv b) {
  a = app(a, val(b), len_of(b));
  jfree(b);
  return a;
}
