#!/bin/sh
# Luma as Home on webOS 6, where sam has no blockSystemApp and no
# profile.blockedAppList, so a replaced Home manifest is never reread without
# restarting sam. LG Home there is a native binary, so this leaves its
# manifest alone and bind-mounts a launcher over the binary instead: sam keeps
# launching com.webos.app.home as before, with the same launch data, and the
# launcher execs Luma with it. Unmounting puts LG Home back.
STATE=/var/lib/luma-home6
TARGET=/usr/bin/com.webos.app.home
LUMA=/media/developer/apps/usr/palm/applications/com.ecklf.luma/luma
HOOK=/var/lib/webosbrew/init.d/64-luma-home6

[ "$(id -u)" = 0 ] || { echo 'Run as root.' >&2; exit 1; }

mounted() { grep -q " $TARGET " /proc/mounts; }

# Running processes whose executable is $1; with $2, only those whose
# command line also contains it.
pids() {
  for dir in /proc/[0-9]*; do
    [ "$(readlink "$dir/exe" 2>/dev/null)" = "$1" ] || continue
    [ -z "$2" ] || tr '\0' ' ' <"$dir/cmdline" 2>/dev/null | grep -q "$2" || continue
    echo "${dir#/proc/}"
  done
}

write_launcher() {
  mkdir -p "$STATE" && chmod 755 "$STATE" || return 1
  cat >"$STATE/launcher" <<EOF
#!/bin/sh
# Bind-mounted over $TARGET by $STATE/home6.sh.
if [ -x "$LUMA" ]; then
  exec "$LUMA" "\$@" 2>>"$STATE/launcher.log"
fi
# Luma is gone: put LG's Home back and run it with the same launch data.
umount -l "$TARGET"
exec "$TARGET" "\$@"
EOF
  chmod 755 "$STATE/launcher"
}

apply() {
  [ -x "$LUMA" ] || { echo "Luma is not installed at $LUMA; LG Home stays." >&2; return 1; }
  [ -x "$STATE/launcher" ] || write_launcher || return 1
  if ! mounted; then
    mount --bind "$STATE/launcher" "$TARGET" || return 1
  fi
  # LG Home started before the mount keeps running its own binary; stop it so
  # sam starts Home again, now through the launcher.
  for pid in $(pids "$TARGET"); do kill "$pid"; done
  echo 'Luma is Home.'
}

disable() {
  rm -f "$HOOK"
  if mounted; then umount "$TARGET" 2>/dev/null || umount -l "$TARGET" || return 1; fi
  for pid in $(pids "$LUMA" com.webos.app.home); do kill "$pid"; done
  echo 'LG Home is back.'
}

case "${1:-status}" in
  enable)
    write_launcher || exit 1
    [ "$0" = "$STATE/home6.sh" ] || cp "$0" "$STATE/home6.sh" || exit 1
    apply || exit 1
    printf '#!/bin/sh\nexec sh %s boot\n' "$STATE/home6.sh" >"$HOOK" && chmod 755 "$HOOK"
    echo "Applied again at every cold boot by $HOOK."
    ;;
  apply) apply ;;
  boot)
    # The boot hook: give sam and LG Home time to start first.
    (sleep 5; apply) </dev/null >>"$STATE/boot.log" 2>&1 &
    ;;
  disable | restore) disable ;;
  status)
    mounted && echo 'Launcher mounted over LG Home.' || echo 'LG Home in place.'
    [ -f "$HOOK" ] && echo "Boot hook: $HOOK" || echo 'No boot hook.'
    echo "LG Home processes: $(pids "$TARGET" | tr '\n' ' ')"
    echo "Luma Home processes: $(pids "$LUMA" com.webos.app.home | tr '\n' ' ')"
    ;;
  *) echo 'Usage: home6.sh enable | disable | status' >&2; exit 1 ;;
esac
