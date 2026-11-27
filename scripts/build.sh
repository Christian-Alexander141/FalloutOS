#!/bin/sh
# Full stage-1 build: fetch + verify, kernel with built-in initramfs, boot.img.
. "$(dirname "$0")/lib.sh"
"$REPO/scripts/fetch-sources.sh" toolchain
"$REPO/scripts/build-kernel.sh"
"$REPO/scripts/build-bootimg.sh"
