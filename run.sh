#!/bin/bash

qemu-system-x86_64 -drive format=raw,file=target/x86_64-loony_os/debug/bootimage-loony_os.bin
qemu-system-x86_64 -drive format=raw,file=target/x86_64-loony_os/debug/bootimage-loony_os.bin
