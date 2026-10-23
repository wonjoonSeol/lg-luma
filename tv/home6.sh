#!/bin/sh
# Luma as Home on webOS 6, where sam has no blockSystemApp and no
# profile.blockedAppList, so a replaced Home manifest is never reread without
# restarting sam. LG Home there is a native binary, so this leaves its
# manifest alone and bind-mounts a launcher over the binary instead: sam keeps
# launching com.webos.app.home as before, with the same launch data, and the
# launcher execs Luma with it. Luma then runs itself from the binary's path in a
# private mount namespace, so it can register with sam and the Home key relaunches
# it instead of restarting it (development.md). Unmounting puts LG Home back.
STATE=/var/lib/luma-home6
TARGET=/usr/bin/com.webos.app.home
LUMA=/media/developer/apps/usr/palm/applications/com.ecklf.luma/luma
HOOK=/var/lib/webosbrew/init.d/64-luma-home6

[ "$(id -u)" = 0 ] || { echo 'Run as root.' >&2; exit 1; }

mounted() { grep -q " $TARGET " /proc/mounts; }

# LG Home's own process: its binary, in the system's mount namespace.
lg_home_pids() {
  ns=$(readlink /proc/1/ns/mnt)
  for dir in /proc/[0-9]*; do
    [ "$(readlink "$dir/exe" 2>/dev/null)" = "$TARGET" ] || continue
    [ "$(readlink "$dir/ns/mnt" 2>/dev/null)" = "$ns" ] || continue
    echo "${dir#/proc/}"
  done
}

# Luma running as Home: from its own path with Home's launch data, or, after
# switching identity, from $TARGET in its own private mount namespace.
luma_pids() {
  ns=$(readlink /proc/1/ns/mnt)
  for dir in /proc/[0-9]*; do
    exe=$(readlink "$dir/exe" 2>/dev/null) || continue
    case "$exe" in
      "$LUMA" | "$LUMA (deleted)")
        tr '\0' ' ' <"$dir/cmdline" 2>/dev/null | grep -q com.webos.app.home || continue
        ;;
      "$TARGET" | "$TARGET (deleted)")
        [ "$(readlink "$dir/ns/mnt" 2>/dev/null)" != "$ns" ] || continue
        ;;
      *) continue ;;
    esac
    echo "${dir#/proc/}"
  done
}

write_launcher() {
  mkdir -p "$STATE" && chmod 755 "$STATE" || return 1
  cat >"$STATE/launcher" <<EOF
#!/bin/sh
# Bind-mounted over $TARGET by $STATE/home6.sh.
if [ -x "$LUMA" ]; then
  # Luma runs itself from $TARGET in a private mount namespace, so it has LG Home's
  # bus identity and can register with SAM instead of being restarted by the Home key.
  export LUMA_HOME_IDENTITY=1
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
  for pid in $(lg_home_pids); do kill "$pid"; done
  echo 'Luma is Home.'
}

disable() {
  rm -f "$HOOK"
  if mounted; then umount "$TARGET" 2>/dev/null || umount -l "$TARGET" || return 1; fi
  for pid in $(luma_pids); do kill "$pid"; done
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
    echo "LG Home processes: $(lg_home_pids | tr '\n' ' ')"
    echo "Luma Home processes: $(luma_pids | tr '\n' ' ')"
    ;;
  *) echo 'Usage: home6.sh enable | disable | status' >&2; exit 1 ;;
esac
