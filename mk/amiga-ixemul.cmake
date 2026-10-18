# CMake toolchain file for the m68k AmigaOS + ixemul cross build (the CMake
# counterpart of M68K_ENV in mk/common.mk). The recipe driver passes:
#   UPTERM_SYSROOT  build/sysroot/UP-Term (headers in include/, libraries in lib/)
#   UPTERM_CPU      -m68020
#   UPTERM_LIBS     libraries every link needs, after the objects (libixcompat.a)
#   UPTERM_STACK_OBJ  the $STACK: cookie object (optional)
set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR m68k)
set(CMAKE_C_COMPILER ${UPTERM_ROOT}/tools/m68k-cc)
set(CMAKE_AR ${UPTERM_CROSS}ar CACHE FILEPATH "")
set(CMAKE_RANLIB ${UPTERM_CROSS}ranlib CACHE FILEPATH "")
set(CMAKE_STRIP ${UPTERM_CROSS}strip CACHE FILEPATH "")
# the compiler is known to work, and a link test would need the whole cookie
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
set(CMAKE_C_FLAGS_INIT "${UPTERM_CPU} -I${UPTERM_SYSROOT}/include")
set(CMAKE_EXE_LINKER_FLAGS_INIT "-L${UPTERM_SYSROOT}/lib ${UPTERM_STACK_OBJ}")
set(CMAKE_C_STANDARD_LIBRARIES_INIT "${UPTERM_LIBS}")
set(CMAKE_C_STANDARD_LIBRARIES "${UPTERM_LIBS}")
# only the sysroot has libraries and headers; host programs stay the host's
set(CMAKE_FIND_ROOT_PATH ${UPTERM_SYSROOT})
set(CMAKE_PREFIX_PATH ${UPTERM_SYSROOT})
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
set(CMAKE_FIND_LIBRARY_SUFFIXES .a)
set(BUILD_SHARED_LIBS OFF)
