#!/bin/sh
# Pack the stage-1 boot image for HTC hboot.
# Input:  $OUT/zImage-dtb (from build-kernel.sh, initramfs built in)
# Output: $OUT/boot-htc-m7-stage1.img
#
# Test without writing to the phone:  fastboot boot boot-htc-m7-stage1.img
# Flashing is a separate, explicit decision (see docs/htc-m7/06-testplan.md).

. "$(dirname "$0")/lib.sh"
need python3 cpio gzip

[ -s "$OUT/zImage-dtb" ] || die "run scripts/build-kernel.sh first"

# hboot expects a ramdisk; the real initramfs is built into the kernel, so
# pass an empty (trailer-only) archive.
empty=$OUT/empty-ramdisk.gz
(cd /var/empty 2>/dev/null || cd /; printf '' |
	cpio --quiet -o -H newc --reproducible -R 0:0) | gzip -9n > "$empty"

# clk/pd/regulator_ignore_unused: keep what hboot enabled for the display
# running, and keep the MDP registers readable for the probe.
cmdline="clk_ignore_unused pd_ignore_unused regulator_ignore_unused console=tty0 loglevel=7"

python3 -I "$REPO/scripts/bootimg.py" pack \
	--kernel "$OUT/zImage-dtb" \
	--ramdisk "$empty" \
	--out "$OUT/boot-htc-m7-stage1.img" \
	--name falloutos \
	--cmdline "$cmdline" \
	--base "$BOOT_BASE" \
	--kernel-offset "$BOOT_KERNEL_OFFSET" \
	--ramdisk-offset "$BOOT_RAMDISK_OFFSET" \
	--second-offset "$BOOT_SECOND_OFFSET" \
	--tags-offset "$BOOT_TAGS_OFFSET" \
	--pagesize "$BOOT_PAGESIZE" \
	--max-size "$BOOT_PARTITION_SIZE"
python3 -I "$REPO/scripts/bootimg.py" info "$OUT/boot-htc-m7-stage1.img"
(cd "$OUT" && sha256sum boot-htc-m7-stage1.img)
