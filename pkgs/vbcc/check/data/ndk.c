/* the cfg finds the NDK headers (NDKINC:) and the vbcc inline pragmas: a dos.library call */
#include <exec/types.h>
#include <dos/dos.h>
#include <proto/dos.h>

int main(void)
{
	Write(Output(), "VBCC-NDK-OK\n", 12);
	return 0;
}
