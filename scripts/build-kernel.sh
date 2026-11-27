#!/bin/sh
# Build the mainline kernel and DTB for the HTC One M7.
#
#   scripts/build-kernel.sh            # stage 1: initramfs built into zImage
#   scripts/build-kernel.sh --no-initramfs
#
# Steps: reset the kernel tree to KERNEL_COMMIT, apply kernel/patches/*,
# start from the pmaports config, merge kernel/config/htc-m7-bringup.config,
# build zImage + DTB and append the DTB (hboot does not pass one).
# Output: $OUT/zImage-dtb, $OUT/qcom-apq8064-htc-m7.dtb, $OUT/kernel.config

. "$(dirname "$0")/lib.sh"
need git make bc bison flex perl python3 cpio

embed=1
[ "${1:-}" = --no-initramfs ] && embed=0

CROSS_COMPILE=$TOOLCHAIN_DIR/$TOOLCHAIN_PREFIX
[ -x "${CROSS_COMPILE}gcc" ] ||
	die "cross compiler missing, run scripts/fetch-sources.sh toolchain"

# Pristine tree at the pinned commit plus our patches.
[ -z "$(git -C "$KERNEL_SRC" status --porcelain)" ] ||
	die "$KERNEL_SRC has local changes"
git -C "$KERNEL_SRC" checkout -q -B falloutos-build "$KERNEL_COMMIT"
for p in "$REPO"/kernel/patches/*.patch; do
	msg "applying $(basename "$p")"
	git -C "$KERNEL_SRC" -c user.name=falloutos -c user.email=build@falloutos \
		-c commit.gpgsign=false am -q --committer-date-is-author-date "$p"
done

mkdir -p "$KERNEL_OBJ" "$OUT"
cp "$PMAPORTS/$KERNEL_BASE_CONFIG" "$KERNEL_OBJ/.config.base"
check_hash sha512 "$KERNEL_BASE_CONFIG_SHA512" "$KERNEL_OBJ/.config.base"

kmake() {
	# LOCALVERSION= keeps setlocalversion from appending "+" for the
	# patched (untagged) tree.
	make -C "$KERNEL_SRC" O="$KERNEL_OBJ" ARCH=arm \
		CROSS_COMPILE="$CROSS_COMPILE" LOCALVERSION= \
		-j"$(nproc)" "$@"
}

ARCH=arm "$KERNEL_SRC/scripts/kconfig/merge_config.sh" -m -O "$KERNEL_OBJ" \
	"$KERNEL_OBJ/.config.base" "$REPO/kernel/config/htc-m7-bringup.config"

if [ $embed -eq 1 ]; then
	"$REPO/scripts/build-initramfs.sh"
	# Relative to the build tree, so no host path ends up in the config.
	cp "$OUT/initramfs-stage1.cpio" "$KERNEL_OBJ/initramfs-stage1.cpio"
	"$KERNEL_SRC/scripts/config" --file "$KERNEL_OBJ/.config" \
		--set-str INITRAMFS_SOURCE "initramfs-stage1.cpio" \
		--enable INITRAMFS_COMPRESSION_XZ
fi
kmake olddefconfig

# Every value of the fragment must survive olddefconfig.
grep -E '^(CONFIG_|# CONFIG_)' "$REPO/kernel/config/htc-m7-bringup.config" |
while IFS= read -r line; do
	grep -qxF "$line" "$KERNEL_OBJ/.config" || die "config not applied: $line"
done

kmake zImage qcom/qcom-apq8064-htc-m7.dtb

cp "$KERNEL_OBJ/.config" "$OUT/kernel.config"
cp "$KERNEL_OBJ/arch/arm/boot/dts/qcom/qcom-apq8064-htc-m7.dtb" "$OUT/"
cat "$KERNEL_OBJ/arch/arm/boot/zImage" "$OUT/qcom-apq8064-htc-m7.dtb" > "$OUT/zImage-dtb"
cat "$KERNEL_OBJ/include/config/kernel.release" > "$OUT/kernel.release"
msg "kernel $(cat "$OUT/kernel.release")"
(cd "$OUT" && sha256sum zImage-dtb qcom-apq8064-htc-m7.dtb kernel.config)
