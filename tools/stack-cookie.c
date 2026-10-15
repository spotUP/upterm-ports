/* The "$STACK: n" cookie (AmigaOS 3.2 rule; vsh honours it on 3.1 too, vtcon
 * ledger P8): the stack a program asks for in its own file. Linked into a
 * package whose recipe sets <pkg>_STACK. */
#define STR2(x) #x
#define STR(x) STR2(x)
const char __upterm_stack_cookie[] __attribute__((used)) = "$STACK: " STR(STACK);
/* <pkg>_STACK_VAR: also the __stack variable ixemul's startup reads (it
 * extends the stack to that size at the program's start). The cookie is read
 * by vsh when it starts the program itself; a program started by vfork + exec
 * (ptyrun, a script's child) gets only what __stack asks for. */
#ifdef STACK_VAR
unsigned long __stack = STACK;
#endif
