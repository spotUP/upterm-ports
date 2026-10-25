# CMake on AmigaOS 3.x: feasibility (2026-10-26)

Answer: ported natively? NO (pkgs/ has 46 packages, no cmake). Cross side: YES (mk/amiga-ixemul.cmake + CMAKE_M68K in mk/common.mk:54-61, used by opkg).

## Facts measured
- Compiler for recipes: ~/opt/amiga/bin/m68k-amigaos-gcc 6.5.0b (bebbo), via tools/m68k-cc (C only: no CXX anywhere in mk/ or pkgs/). libstdc++.a exists for 6.5 (C++14 at best). ~/opt/amiga16 has gcc 16.1.1b with libstdc++.a (C++20 capable), but no recipe uses it and no ixemul-linked libstdc++ check was done (unverified).
- Package pattern: pkgs/<p>/recipe.mk (~45 lines for git, perl) + patches/ (git 1 patch, perl 1 patch). Vars: <p>_VERSION/_URL/_SHA256/_DEPS/_CONFIGURE/_CMAKE.
- Host reference: cmake 4.4.3 binary = 14.3 MB on arm64 (m68k would be roughly 6-10 MB hunk, stripped; unverified estimate). Build needs C++17 plus many GB-scale link RAM on host; runtime wants several MB per project configure (tens of MB for real trees).
- libuv: already ported in /Users/spot/Code/UP-Term/neovim-amiga/vendor/libuv (with luv). Reusable, not yet a pkgs/ package.
- Present in pkgs/: zlib, xz, bzip2, libarchive. Missing: libcurl (cmake needs it for file(DOWNLOAD)/ctest submit, can be disabled), expat, jsoncpp, nghttp2, rhash, cppdap, cmsys (bundled).

## Feasibility
| Approach | Blockers | Deps missing | Size (agent-days) | Value |
|---|---|---|---|---|
| Native latest cmake (3.26+/4.x) | needs C++17 + libstdc++ (std::filesystem) + threads + libuv under ixemul; only gcc16 is capable, and it is not wired into recipes; huge binary, slow on 68060, RAM-hungry | libuv pkg, expat, jsoncpp, rhash, nghttp2 (curl optional off) | 10-20, high risk | Low: no CMake-based software builds natively on the Amiga yet; no compiler on target either |
| Native old cmake 3.10 (C++11) | gcc 6.5 can build it (C++14 ok); bootstrap script cross-compile needs host cmake or `bootstrap` run on target; libuv 1.x needed (ported); fork/exec via ixemul ok (vfork patch seen in git) | libuv pkg, curl off, expat/jsoncpp bundled | 4-7, medium risk | Low-medium: runs old CMakeLists only (cmake_minimum_required fails above 3.10 features) |
| Cross-only, adopt AmigaPorts ideas | none | none | 0.5 | Medium: improves CMAKE_CXX support, CPU/FPU knobs |

## AmigaPorts AmigaCMakeCrossToolchains vs mk/amiga-ixemul.cmake
- Does it target ixemul? Only as an option: M68K_CRT (default nix20, accepts nix13 clib2 ixemul newlib none custom) emits -mcrt=<type>. Default is libnix, not ixemul. Compiler = bebbo gcc (M68K_COMPILER=Bebbo marker), also a gcc10 variant, bartman (vbcc-like), PPC, AROS.
- Differences, worth copying:
  - C++ compiler: sets CMAKE_CXX_COMPILER (g++), CXX init flags, TOOLCHAIN_CXXFLAGS. Ours is C only: required before any C++ package.
  - M68K_CPU / M68K_FPU cache knobs (-m<cpu>, -m<fpu>-float) instead of the single UPTERM_CPU string.
  - Assembler: CMAKE_ASM_COMPILER = gcc -c plus ASM flags; ours sets none (ASM projects fail).
  - -fomit-frame-pointer in common flags; CMAKE_POLICY CMP0057 NEW.
  - CMAKE_SYSROOT set (ours only sets FIND_ROOT_PATH + -I/-L flags); CMAKE_SYSTEM_NAME AmigaOS if a platform file exists, else Generic.
  - Same as ours: try-compile STATIC_LIBRARY, .a suffix, BUILD_SHARED_LIBS OFF, find modes PROGRAM NEVER / rest ONLY.
- Do NOT copy: CMAKE_SYSTEM_NAME=AmigaOS (needs a Generic.cmake copy into the host cmake install; Generic works already), libnix default, /opt/<prefix> path layout, VASM/ndk-include parts, -ldebug.

## Recommendation
Do not port cmake natively now (no on-target compiler to use it, no C++ in the recipe system). Extend mk/amiga-ixemul.cmake with a CXX compiler/flags and ASM block when the first C++ package arrives; revisit native cmake 3.10 only after libuv is packaged and a native toolchain package exists.
