# shellcheck shell=sh
# FalloutOS build helpers. Sourced by the other scripts.

set -eu

REPO=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK=${WORK:-$REPO/work}
OUT=${OUT:-$REPO/out}

# shellcheck source=../sources.lock
. "$REPO/sources.lock"

export SOURCE_DATE_EPOCH KBUILD_BUILD_USER KBUILD_BUILD_HOST KBUILD_BUILD_VERSION
KBUILD_BUILD_TIMESTAMP=$(LC_ALL=C date -u -d "@$SOURCE_DATE_EPOCH")
export KBUILD_BUILD_TIMESTAMP
export LC_ALL=C TZ=UTC

msg() { printf '==> %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

need() {
	for t in "$@"; do
		command -v "$t" >/dev/null 2>&1 || die "missing host tool: $t"
	done
}

# check_hash ALGO EXPECTED FILE
check_hash() {
	got=$("${1}sum" "$3" | cut -d' ' -f1)
	[ "$got" = "$2" ] || die "$1 mismatch for $3: expected $2, got $got"
}

# fetch URL DEST [FALLBACK_URL]
fetch() {
	[ -s "$2" ] && return 0
	mkdir -p "$(dirname "$2")"
	curl -fsSL --retry 3 -o "$2.part" "$1" ||
		{ [ -n "${3:-}" ] && curl -fsSL --retry 3 -o "$2.part" "$3"; } ||
		die "download failed: $1"
	mv "$2.part" "$2"
}

KERNEL_SRC=$WORK/src/linux
KERNEL_OBJ=$WORK/build/linux
PMAPORTS=$WORK/src/pmaports
TOOLCHAIN_DIR=$WORK/toolchain
BUSYBOX=$WORK/busybox/bin/busybox
