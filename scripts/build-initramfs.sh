#!/bin/sh
# Build the stage-1 initramfs as a reproducible newc cpio archive.
# Output: $OUT/initramfs-stage1.cpio (uncompressed; the kernel embeds and
# compresses it, see build-kernel.sh).

. "$(dirname "$0")/lib.sh"
need python3
[ -x "$BUSYBOX" ] || die "busybox missing, run scripts/fetch-sources.sh"
check_hash sha256 "$BUSYBOX_BIN_SHA256" "$BUSYBOX"

mkdir -p "$OUT"
spec=$OUT/initramfs-stage1.spec
I=$REPO/initramfs
cat > "$spec" <<EOF
dir   /bin                               0755 0 0
file  /bin/busybox  $BUSYBOX             0755 0 0
slink /bin/sh       busybox              0777 0 0
dir   /dev                               0755 0 0
nod   /dev/console                       0600 0 0 c 5 1
nod   /dev/null                          0666 0 0 c 1 3
dir   /etc                               0755 0 0
file  /etc/udhcpd.conf  $I/udhcpd.conf   0644 0 0
file  /init         $I/init              0755 0 0
dir   /proc                              0755 0 0
dir   /run                               0755 0 0
dir   /sys                               0755 0 0
dir   /tmp                               1777 0 0
dir   /usr                               0755 0 0
dir   /usr/share                         0755 0 0
dir   /usr/share/falloutos               0755 0 0
file  /usr/share/falloutos/m7-probe  $I/m7-probe  0755 0 0
EOF

python3 -I "$REPO/scripts/mkcpio.py" "$spec" "$OUT/initramfs-stage1.cpio" \
	--mtime "$SOURCE_DATE_EPOCH"
msg "$OUT/initramfs-stage1.cpio ($(wc -c < "$OUT/initramfs-stage1.cpio") bytes)"
(cd "$OUT" && sha256sum initramfs-stage1.cpio)
