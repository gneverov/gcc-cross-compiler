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

find_program(MESON meson)

# Build picolibc (stage 1) using the pre-existing (old) gcc
add_custom_command(
    OUTPUT picolibc-stage1/build.ninja
    COMMAND 
        ${MESON} 
        setup
        --reconfigure
        --cross-file=${CMAKE_CURRENT_SOURCE_DIR}/cross-thumbv6m-none-eabi.txt
        -Dprefix=${PREFIX}/arm-none-eabi
        -Dtests=false
        -Dmultilib=false
        -Dposix-console=true
        -Dsemihost=false
        -Dpicolib=true
        -Dpicocrt=false
        -Dcrt-runtime-size=true
        -Dthread-local-storage=true
        picolibc-stage1
        ${CMAKE_CURRENT_SOURCE_DIR}/picolibc
    VERBATIM
)

find_program(NINJA ninja)

add_custom_command(
    OUTPUT picolibc-stage1/done
    COMMAND ${NINJA}
    COMMAND ${NINJA} install
    COMMAND touch done
    WORKING_DIRECTORY picolibc-stage1
    DEPENDS picolibc-stage1/build.ninja
    VERBATIM
)

# Build gcc using picolibc (stage 1) 
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
    DEPENDS gcc/Makefile binutils/done picolibc-stage1/done
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

# Build picolibc (stage 2) using the newly built gcc
add_custom_command(
    OUTPUT picolibc-stage2/build.ninja
    COMMAND 
        ${USE_NEW_GCC}
        ${MESON} 
        setup
        --reconfigure
        --cross-file=${CMAKE_CURRENT_SOURCE_DIR}/cross-thumbv6m-none-eabi.txt
        -Dprefix=${PREFIX}/arm-none-eabi
        -Dtests=false
        -Dmultilib=false
        -Dposix-console=true
        -Dsemihost=false
        -Dpicolib=true
        -Dpicocrt=false
        -Dcrt-runtime-size=true
        -Dthread-local-storage=true
        picolibc-stage2
        ${CMAKE_CURRENT_SOURCE_DIR}/picolibc
    DEPENDS gcc/done check_gcc
    VERBATIM
    COMMAND_EXPAND_LISTS
)

add_custom_command(
    OUTPUT picolibc-stage2/done
    COMMAND ${USE_NEW_GCC} ${NINJA}
    COMMAND ${USE_NEW_GCC} ${NINJA} install
    COMMAND touch done
    WORKING_DIRECTORY picolibc-stage2
    DEPENDS picolibc-stage2/build.ninja
    VERBATIM
    COMMAND_EXPAND_LISTS
)

# Main build target
add_custom_target(build ALL
    DEPENDS picolibc-stage2/done
    VERBATIM
)

install(DIRECTORY ${PREFIX}/ DESTINATION . USE_SOURCE_PERMISSIONS)
