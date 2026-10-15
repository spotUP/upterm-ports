#include <stdio.h>

#define LIMIT 10

struct point { int x; int y; };

static int add(int a, int b)
{
	return a + b;
}

int main(void)
{
	struct point p = { 1, 2 };
	printf("%d\n", add(p.x, p.y));
	return 0;
}
