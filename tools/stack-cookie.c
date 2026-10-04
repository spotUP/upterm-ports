/* The "$STACK: n" cookie (AmigaOS 3.2 rule; vsh honours it on 3.1 too, vtcon
 * ledger P8): the stack a program asks for in its own file. Linked into a
 * package whose recipe sets <pkg>_STACK. */
#define STR2(x) #x
#define STR(x) STR2(x)
const char __upterm_stack_cookie[] __attribute__((used)) = "$STACK: " STR(STACK);
