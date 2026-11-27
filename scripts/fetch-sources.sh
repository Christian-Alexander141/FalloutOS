#!/bin/sh
# Fetch and verify every pinned input from sources.lock into $WORK.
#
#   scripts/fetch-sources.sh             # sources + busybox
#   scripts/fetch-sources.sh toolchain   # additionally the cross compiler
#
# Nothing here executes downloaded code: archives are only verified and
# unpacked. The toolchain is fetched only when asked for explicitly.

. "$(dirname "$0")/lib.sh"
need git curl gpg sha256sum sha512sum ar tar xz

# git_at DIR URL COMMIT [SPARSE_PATH...]: checkout of exactly COMMIT
git_at() {
	dir=$1 url=$2 commit=$3
	shift 3
	if [ ! -d "$dir/.git" ]; then
		git init -q "$dir"
		git -C "$dir" remote add origin "$url"
	fi
	if [ $# -gt 0 ]; then
		git -C "$dir" sparse-checkout set --no-cone "$@"
	fi
	if ! git -C "$dir" cat-file -e "$commit^{commit}" 2>/dev/null; then
		msg "fetching $url @ $commit"
		git -C "$dir" fetch -q --depth 1 --filter=blob:none origin "$commit"
	fi
	git -C "$dir" checkout -q --detach "$commit"
	[ "$(git -C "$dir" rev-parse HEAD)" = "$commit" ] || die "$dir not at $commit"
}

git_at "$PMAPORTS" "$PMAPORTS_URL" "$PMAPORTS_COMMIT" \
	"/$KERNEL_BASE_CONFIG" \
	"/device/testing/linux-postmarketos-qcom-apq8064/" \
	"/device/archived/device-htc-m7/" \
	"/device/archived/linux-htc-m7/"
check_hash sha512 "$KERNEL_BASE_CONFIG_SHA512" "$PMAPORTS/$KERNEL_BASE_CONFIG"
msg "pmaports ok"

git_at "$KERNEL_SRC" "$KERNEL_URL" "$KERNEL_COMMIT"
msg "kernel source ok ($(make -s -C "$KERNEL_SRC" kernelversion))"

# busybox-static from Debian (pinned .deb hash, then the binary hash)
deb=$WORK/dl/$BUSYBOX_DEB
fetch "$BUSYBOX_DEB_URL" "$deb" "$BUSYBOX_DEB_SNAPSHOT_URL"
check_hash sha256 "$BUSYBOX_DEB_SHA256" "$deb"
tmp=$(mktemp -d)
(cd "$tmp" && ar x "$deb" data.tar.xz && tar xJf data.tar.xz ./usr/bin/busybox)
mkdir -p "$(dirname "$BUSYBOX")"
mv "$tmp/usr/bin/busybox" "$BUSYBOX"
rm -rf "$tmp"
check_hash sha256 "$BUSYBOX_BIN_SHA256" "$BUSYBOX"
msg "busybox ok"

if [ "${1:-}" = toolchain ]; then
	dl=$WORK/dl/toolchain
	fetch "$TOOLCHAIN_BASE/sha256sums.asc" "$dl/sha256sums.asc"
	fetch "https://git.kernel.org/pub/scm/docs/kernel/pgpkeys.git/plain/keys/${TOOLCHAIN_SIGNER_FPR#????????????????????????}.asc" \
		"$dl/signer.asc"
	GNUPGHOME=$dl/gnupg
	export GNUPGHOME
	mkdir -p -m 700 "$GNUPGHOME"
	gpg -q --import "$dl/signer.asc" 2>/dev/null
	gpg --status-fd 1 --verify "$dl/sha256sums.asc" 2>/dev/null |
		grep -q "VALIDSIG $TOOLCHAIN_SIGNER_FPR" ||
		die "sha256sums.asc: no valid signature from $TOOLCHAIN_SIGNER_FPR"
	grep -q "^$TOOLCHAIN_SHA256  $TOOLCHAIN_FILE\$" "$dl/sha256sums.asc" ||
		die "pinned toolchain hash not in signed sha256sums.asc"
	fetch "$TOOLCHAIN_BASE/$TOOLCHAIN_FILE" "$dl/$TOOLCHAIN_FILE"
	check_hash sha256 "$TOOLCHAIN_SHA256" "$dl/$TOOLCHAIN_FILE"
	mkdir -p "$TOOLCHAIN_DIR"
	tar xJf "$dl/$TOOLCHAIN_FILE" -C "$TOOLCHAIN_DIR"
	msg "toolchain ok"
fi
