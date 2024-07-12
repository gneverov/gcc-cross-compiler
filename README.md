# Arm GNU toolchain for RP2040
This project builds a custom version of the Arm GNU toolchain specifically for running [Picolibc](https://github.com/picolibc/picolibc) on the multicore [RP2040](https://en.wikipedia.org/wiki/RP2040) microcontroller.

Based on the [script](https://gist.github.com/badcf00d/2f6054441375d9c94896aaa8e878ab4f).

## Why?
The standard GNU toolchain built by [ARM](https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads) is configured with `--disable-tls`. Because of this, Picolibc cannot be compiled using thread local storage (TLS), which prevents it being used in a multicore context on the dual-core RP2040 processor. This project rebuilds the GNU toolchain from sources, without disabling TLS, and then builds Picolibc using it. 

## How to build
```
cmake -B ./build
cmake --build ./build -j<n>
cmake --install ./build --prefix <path>
```
- *n* - number of parallel Make jobs
- *path* - path to install toolchain
