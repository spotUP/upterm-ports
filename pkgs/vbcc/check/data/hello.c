#include <stdio.h>

/* a test program: no __stack and no $STACK cookie (vtcon RULES.md applies to the programs we ship) */
int main(void)
{
	puts("VBCC-NATIVE-OK 0.9h");
	return 0;
}
