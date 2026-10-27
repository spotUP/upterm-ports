/* fpu_probe_test.c: the pure decision of patches/0056 over faked AttnFlags values. Includes upkg_cpu.c itself. */
#include <stdio.h>
#include "upkg_cpu.c"

static int bad;
static void want(const char *what, unsigned attn, int yes)
{
    int got = upkg_fpu_arch_wanted(attn);
    if (got != yes) { printf("[FAIL] fpu_probe: %s (flags 0x%x): got %d, want %d\n", what, attn, got, yes); bad = 1; }
}

int main(void)
{
    /* exec sets AFF_68010/68020/68030 for each lower CPU too; the 040/060 cases carry the lower bits like the real flags */
    const unsigned c020 = 0x3, c030 = 0x7, c040 = 0xf | UPKG_AFF_68040, c060 = c040 | UPKG_AFF_68060;
    want("060 + FPU40", c060 | UPKG_AFF_FPU40, 1);
    want("040 + FPU40", c040 | UPKG_AFF_FPU40, 1);
    want("060 + 68882", c060 | UPKG_AFF_68881 | UPKG_AFF_68882, 1);
    want("060 without FPU (LC060)", c060, 0);
    want("040 without FPU (LC040)", c040, 0);
    want("030 + 68882", c030 | UPKG_AFF_68881 | UPKG_AFF_68882, 0);
    want("030 + 68881", c030 | UPKG_AFF_68881, 0);
    want("020", c020, 0);
    want("020 + 68881", c020 | UPKG_AFF_68881, 0);
    want("no flags", 0, 0);
    if (!bad) printf("[OK] fpu_probe_test: 060/040 + FPU yes; LC060, LC040, 030 + 68882, 020 no\n");
    return bad;
}
