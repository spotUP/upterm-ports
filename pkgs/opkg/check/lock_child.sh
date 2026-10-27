#!/bin/sh
# lock_child.sh UPKG: host check of patches/0053: a download child must not hold upkg's lock descriptor.
# opkg_lock() lockf()s a descriptor that the vfork'd curl inherited; on ixemul the lock is tied to the open
# file, so after Ctrl-C of upkg the orphan curl kept it and the next `upkg update` failed with "Could not
# lock" and rc 20. Host POSIX record locks die with the locking process, so the host check looks at the
# cause instead: a fake curl lists its own open files (/proc/PID/fd, else lsof) and must not find the lock file.
#   sh pkgs/opkg/check/lock_child.sh build/host/opkg/inst/bin/upkg
set -eu
upkg=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
w=$(mktemp -d "${TMPDIR:-/tmp}/lockchild.XXXXXX")
w=$(cd "$w" && pwd -P)
trap 'rm -rf "$w"' EXIT
mkdir "$w/etc" "$w/bin" "$w/c.lists_dir" "$w/c.info_dir" "$w/c.cache_dir"
: > "$w/c.status_file"
cat > "$w/bin/curl" <<EOF
#!/bin/sh
echo run >> "$w/ran"
if [ -d /proc/\$\$/fd ]; then ls -l /proc/\$\$/fd; else lsof -p \$\$ 2>/dev/null; fi > "$w/fds"
exit 1
EOF
chmod +x "$w/bin/curl"
{ echo "arch m68k-amigaos 10"; echo "dest root /"; echo "src/gz feed http://127.0.0.1:9/x"
  for o in lists_dir lock_file info_dir status_file cache_dir; do echo "option $o $w/c.$o"; done; } > "$w/etc/upkg.conf"
OPKG_CONF_DIR="$w/etc" PATH="$w/bin:$PATH" "$upkg" update >/dev/null 2>&1 || true
[ -f "$w/ran" ] && [ -s "$w/fds" ] || { echo "[FAIL] lock_child: test setup, the fake curl did not run or listed nothing"; exit 1; }
if grep -q "c.lock_file" "$w/fds"; then
  echo "[FAIL] lock_child: the download child holds the lock file open: $(grep c.lock_file "$w/fds" | head -1)"; exit 1
fi
echo "[OK] lock_child: the download child does not hold the lock file"
