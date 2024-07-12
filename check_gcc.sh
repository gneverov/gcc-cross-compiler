#!/bin/bash

# Checks that the GCC on PATH is the newly built GCC
if [ `which arm-none-eabi-gcc` != $1 ]; then
    echo wrong GCC >&2
    exit 1
fi
