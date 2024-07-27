cmake_minimum_required(VERSION 3.27)

project(arm-gnu-toolchain LANGUAGES NONE)

set(PREFIX ${CMAKE_CURRENT_LIST_DIR}/install)

string(TIMESTAMP DATE "%Y-%m-%d")

set(PKGVERSION "Arm GNU Toolchain for RP2040 (${DATE})")

find_program(OLD_GCC arm-none-eabi-gcc)
if(NOT EXISTS ${OLD_GCC})
    message(FATAL_ERROR "Could not find arm-none-eabi-gcc in PATH. A pre-built Arm GNU Toolchain is required to build a new one.")
endif()

if(NOT ${CMAKE_GENERATOR} STREQUAL "Unix Makefiles")
    message(FATAL_ERROR "Only Unix Makefiles generator supported.")
endif()

# Build binutils-gdb
add_custom_command(
    OUTPUT binutils/Makefile
    COMMAND mkdir -p binutils
    COMMAND
        cd binutils && ${CMAKE_CURRENT_SOURCE_DIR}/binutils-gdb/configure
        --target=arm-none-eabi
        --prefix=${PREFIX}
        "--with-pkgversion=${PKGVERSION}"
        --with-sysroot
        --with-lzma
        --with-expat
        --with-python
        --with-isl
        --with-zstd
        --enable-ld=yes
        --enable-gold=no
        --enable-plugins
        --disable-multilib
        --with-mode=thumb
        --with-cpu=cortex-m0plus
        --with-float=soft
        --enable-lto
        --enable-source-highlight
        --disable-werror
        --disable-nls
        --disable-warn-rwx-segments
    VERBATIM
)

add_custom_command(
    OUTPUT binutils/done
    COMMAND $(MAKE)
    COMMAND $(MAKE) install-strip
    COMMAND touch done
    WORKING_DIRECTORY binutils
    DEPENDS binutils/Makefile
    VERBATIM
)

# Build newlib using our "stage1" compiler (this is essentially newlib-nano)
add_custom_command(
    OUTPUT newlib-cygwin/Makefile
    COMMAND mkdir -p newlib-cygwin
    COMMAND
        cd newlib-cygwin && ${CMAKE_CURRENT_SOURCE_DIR}/newlib-cygwin/configure
        --target=arm-none-eabi
        --prefix=${PREFIX}
        --disable-newlib-supplied-syscalls
        --disable-newlib-io-float
        --disable-newlib-io-long-double
        --disable-newlib-io-pos-args
        --disable-newlib-io-c99-formats
        --disable-newlib-io-long-long
        --disable-newlib-multithread
        --disable-newlib-retargetable-locking
        --disable-newlib-wide-orient
        --disable-newlib-fseek-optimization
        --disable-newlib-fvwrite-in-streamio
        --disable-newlib-unbuf-stream-opt
        --disable-newlib-atexit-dynamic-alloc
        --enable-newlib-nano-malloc
        --enable-newlib-nano-formatted-io
        --enable-newlib-global-atexit
        --enable-lite-exit
        --enable-newlib-reent-small
        --disable-multilib
        --with-mode=thumb
        --with-cpu=cortex-m0plus
        --with-float=soft
        --enable-libssp
        --enable-target-optspace
    VERBATIM
)

add_custom_command(
    OUTPUT newlib-cygwin/done
    COMMAND $(MAKE)
    COMMAND $(MAKE) install-strip
    COMMAND touch done
    WORKING_DIRECTORY newlib-cygwin
    DEPENDS newlib-cygwin/Makefile
    VERBATIM
)

# Build gcc using newlib-nano
add_custom_command(
    OUTPUT gcc/Makefile
    COMMAND mkdir -p gcc
    COMMAND
        cd gcc && ${CMAKE_CURRENT_SOURCE_DIR}/gcc/configure
        --prefix=${PREFIX}
        --enable-languages=c,c++
        --target=arm-none-eabi
        "--with-pkgversion=${PKGVERSION}"
        --with-newlib
        --with-sysroot=$PREFIX/arm-none-eabi
        --with-native-system-header-dir=/include
        --disable-multilib
        --with-mode=thumb
        --with-cpu=cortex-m0plus
        --with-float=soft
        --enable-lto
        --enable-target-optspace
        --enable-multiarch
        --disable-libssp
        --disable-nls
        --disable-threads
        --disable-shared
        --disable-tm-clone-registry
    VERBATIM
)

add_custom_command(
    OUTPUT gcc/done
    COMMAND $(MAKE)
    COMMAND $(MAKE) install-strip
    COMMAND touch done
    WORKING_DIRECTORY gcc
    DEPENDS gcc/Makefile binutils/done newlib-cygwin/done
    VERBATIM
)

# Check that by prepending to PATH we run the newly built gcc
set(USE_NEW_GCC ${CMAKE_COMMAND} -E env "PATH=${PREFIX}/bin:$ENV{PATH}")

add_custom_target(check_gcc
    COMMAND ${USE_NEW_GCC} ${CMAKE_CURRENT_SOURCE_DIR}/check_gcc.sh ${PREFIX}/bin/arm-none-eabi-gcc
    DEPENDS gcc/done
    VERBATIM
    COMMAND_EXPAND_LISTS
)

find_program(MESON meson)
find_program(NINJA ninja)
# Build picolibc using the newly built gcc
add_custom_command(
    OUTPUT picolibc/build.ninja
    COMMAND
        ${USE_NEW_GCC}
        ${MESON}
        setup
        --reconfigure
        --cross-file=${CMAKE_CURRENT_SOURCE_DIR}/cross-thumbv6m-none-eabi.txt
        -Dprefix=${PREFIX}/picolibc
        -Dspecsdir=none
        -Dtests=false
        -Dmultilib=false
        -Dposix-console=true
        -Dsemihost=false
        -Dpicolib=true
        -Dpicocrt=false
        -Dnewlib-initfini=false
        -Dcrt-runtime-size=true
        -Dthread-local-storage=true
        -Dnewlib-iconv-encodings=us_ascii,utf_8,utf_16
        picolibc
        ${CMAKE_CURRENT_SOURCE_DIR}/picolibc
    DEPENDS gcc/done check_gcc
    VERBATIM
    COMMAND_EXPAND_LISTS
)

add_custom_command(
    OUTPUT picolibc/done
    COMMAND ${USE_NEW_GCC} ${NINJA}
    COMMAND ${USE_NEW_GCC} ${NINJA} install
    COMMAND touch done
    WORKING_DIRECTORY picolibc
    DEPENDS picolibc/build.ninja
    VERBATIM
    COMMAND_EXPAND_LISTS
)

# Main build target
add_custom_target(build ALL
    DEPENDS gcc/done picolibc/done
    VERBATIM
)

install(DIRECTORY ${PREFIX}/ DESTINATION . USE_SOURCE_PERMISSIONS)
