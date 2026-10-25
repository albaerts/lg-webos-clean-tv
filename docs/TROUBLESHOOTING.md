# Troubleshooting — and the five ways this went black

All of this happened on an LG C3 (webOS 11.2.0) while building the project. Each one is avoided by the current hooks; keep them in mind if you modify anything.

## Black screen after boot, app manager never comes back

**Cause 1 — the hook ran twice.** BusyBox `run-parts` executes *every* executable file in `init.d`, including `30-foo.bak`. Two hooks restarted
the app manager (`sam`) at the same time. → Never keep copies in `init.d`; put them in `/var/lib/webosbrew/off/`.

**Cause 2 — the system-UI monitor flooded the bus.** `/etc/systemd/system/scripts/flutter-systemui-monitor.sh` runs
`luna-send … launch starfish_flutter_systemui &` every second while the system UI is not running. Killing `sam.service` kills the system
UI with it (KillMode=control-group), thousands of `luna-send` pile up on ls-hub (`LUNASERVICEERROR-1033 Try again later`), and sam only ever
processes the backlog. → Never restart `sam.service`. If you must at runtime: `systemctl stop flutter-systemui.service` first, kill stray
`luna-send`, start it again afterwards.

**Cause 3 — `eim.service` deadlock.** `eim` (HDMI-CEC/ARC) has `Requires=sam.service`. Any *explicit* stop/kill/restart of the sam
unit queues an eim restart; during boot eim does not terminate (`deactivating (final-sigkill)`), and the sam start job waits forever.
Check with `systemctl list-jobs`; rescue with `systemctl cancel <eim job id>`.

**Cause 4 — 90 s stop timeout.** Even `kill -9 $(pidof sam)` leaves systemd waiting `TimeoutStopSec=90s` for children in sam's cgroup that
ignore SIGTERM (here: `/usr/palm/applications/airplay/LunaExecutable`), visible only in the `systemd`/`devices` cgroup hierarchies, not in `memory`.

**Cause 5 — nothing in the foreground.** After any sam restart no app is in front → black. You would have to relaunch the previous app yourself.

**The fix for all five:** don't restart sam. `blockSystemApp` + `releaseBlockSystemApp` makes sam re-read one app's manifest in under a second,
pid unchanged, no black frame (`tv/bin/common.sh: reread_app`). Verified on webOS 11.2 (needs `"forceBlockSystemApp":false`, read from
`/etc/palm/schemas/sam/applicationManager.blockSystemApp.schema`).

## The launcher mount "doesn't stick" at boot

webOS remounts the app partitions ~35 s after boot and drops bind mounts made before that. The hook retries every 2 s for up to 80 s.
Count mounts via `/proc/mounts` target paths — `mount(8)` on this firmware does not always print the bind source, so `mount | grep` can report 0 while the mount exists.

## Stacked mounts after running hooks by hand

Every manual run of the hook used to add another bind-mount layer (6'400 entries in `/proc/mounts` made the whole bus sluggish).
The current scripts check `/proc/mounts` first. To unstack: `while [ $(grep -c " <target> " /proc/mounts) -gt 1 ]; do umount <target>; done`.

## `luna-send` prints nothing over SSH

Without a TTY, `luna-send` only prints when called with `-f`. Use `-f`, or `ssh -tt`. Output is empty for ~60–90 s after any sam restart as well.

## Old LG menu appears when pressing Home right after boot

Expected for the first ~26 s: sam still has the Flutter manifest cached until the hook ran. After that the launcher stays.

## Icons missing in the launcher

Run `sh /var/lib/webosbrew/cleantv/bin/refresh.sh` (also runs at boot). WAM blocks `file://` icons from other app directories.

## Reading what happened

`/var/lib/webosbrew/cleantv/log/boot.log` — one block per boot with timestamps. `/var/log/messages` has `sam` launch lines
(`NL_APP_LAUNCH_BEGIN`), `/var/log/bootd.log` shows when bootd put which app in front.
