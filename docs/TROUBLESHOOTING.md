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

## Black screen (or LG's clock screen saver) after a cold start, SAM is fine

**Seen** 2026-10-26 on the reference C3: TV switched off while the launcher was on screen, next boot showed nothing, a few
minutes later LG's screen saver (thin clock on black). `systemctl` said sam and eim were active, the launcher files were mounted
and `getAppInfo` said `type: web`. What differed from the good boots: `bootd` had opened **LG's Flutter Home at 13 s**
(`NL_HOME_SHOWN bootingHome` in `/var/log/messages`), because the TV had been switched off from Home instead of from an HDMI input.

**Cause:** the hook killed that Flutter process and launched the web launcher in the same second. SAM registered the Flutter
process' death *after* the web launch and dropped the new instance as well. Result: WAM kept an orphan web process for
`com.webos.app.home`, SAM no longer listed Home as running, every later `launch` (last-input handler, preload manager, Home key)
hit the orphan: the lifecycle shows only `launch`, never `foreground`, no window is created. The screen is black, and since
nothing changes on it, tvpower starts the screen saver.

**How to tell:** compare three views, the surface manager is the truth about what is on screen:

```bash
luna-send -n 1 -f luna://com.webos.surfacemanager/getForegroundAppInfo '{}'          # what is actually shown
luna-send -n 1 -f luna://com.webos.applicationManager/running '{}'                   # what SAM thinks is running
luna-send -n 1 -f luna://com.webos.service.webappmanager/listRunningApps '{"includeSysApps":true}'   # what WAM holds
luna-send -i -f luna://com.webos.applicationManager/getAppLifeEvents '{"subscribe":true}'            # lifecycle while you launch
```

**Recover without a reboot:** `closeByAppId` through SAM, then `launch`; the launcher was in the foreground two seconds later.
WAM's `closeByProcessId` returned `true` but changed nothing, and `kill -9` of the renderer only made WAM reload the page hidden.

```bash
luna-send -n 1 -f luna://com.webos.applicationManager/closeByAppId '{"id":"com.webos.app.home"}'
luna-send -n 1 -f luna://com.webos.applicationManager/launch '{"id":"com.webos.app.home"}'
```

**Fix in this project:** `close_lg_home` in `tv/bin/common.sh` closes LG Home through SAM and waits until neither the process nor
SAM's running entry exists (kill only as a fallback after 5 s), and `launch_home_verified` checks the surface manager's foreground
app for 15 s and retries up to three times after cleaning up. The hook uses both.

Verified on 2026-10-26 with a reboot from the launcher (so bootd opened LG Home first): LG Home visible at 13 s, launcher in the
foreground from 54 s on and stable afterwards. Note that `closeByAppId` on the Flutter Home returns `true` without ending it; what
matters is waiting until SAM no longer lists Home as running before launching.

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

## The launcher shows the old page after you edited index.html

`closeByAppId` + `launch` brings back the OLD page: the web app manager keeps the instance and just re-shows it. Kill its renderer first
(`activate.sh` and `reload_home` in `common.sh` do this):

```bash
luna-send -n 1 -f luna://com.webos.service.webappmanager/listRunningApps '{"includeSysApps":true}'   # webprocessid of com.webos.app.home
luna-send -n 1 -f luna://com.webos.applicationManager/closeByAppId '{"id":"com.webos.app.home"}'; kill -9 <webprocessid>; sleep 4
luna-send -n 1 -f luna://com.webos.applicationManager/launch '{"id":"com.webos.app.home"}'
```

## An HDMI input does not move in the row

Launch points of inputs are *bookmarks* with a numeric `launchPointId` (e.g. `971517`), not `<app id>_default`. `order.sh` resolves ids
through `listLaunchPoints`; if you call `moveLaunchPoint` by hand, use the numeric id.

## The row order is right in `listLaunchPoints` but the launcher shows the old order

The launcher reads the list only on launch and on `webOSRelaunch`. Launch Home once more (the hook does it after `order.sh`).

## A blocked host still resolves with nslookup

`nslookup` asks connman's DNS proxy directly and bypasses `/etc/hosts`. Processes use the libc resolver, which reads `/etc/hosts` first.
Test with `ping -c1 <host>`: a blocked host answers from `127.0.0.1` / `0.0.0.0`.

## I killed my own SSH session with pkill

`pkill -f /usr/sbin/<name>` also matches the shell whose command line contains that string - your own session. Use `pkill -x <name>`
(exact process name, 15 characters max) or `pgrep -f '^/full/path'` anchored at the start.

## Testing an app with `launch` put it on screen

`applicationManager/launch` always brings the app to the foreground, including hidden ones. Launch `com.webos.app.home` to get back.

## A stopped service is back after a minute

It is a dynamic luna service: ls-hubd respawns it on the next call. Stopping is pointless; overlay the binary with the sleeping stub
(`lean.sh` does this for `sdx`, `uploadd`, `iconnectivity`), or find the caller with `ls-monitor` and stop that.

## The screen saver appears although the TV is "on"

LG's screen saver (a thin clock on black) is started by `tvpower` after a few minutes without a visible surface change. If it appears
right after boot, nothing was drawn: check `getForegroundAppInfo` of the surface manager (cause no. 6 above).

