# How it works

## Pieces

| Path on TV | Purpose |
|---|---|
| `/media/system/apps/usr/palm/applications/com.webos.app.home` | **The live launcher.** A copy of `cleantv/launcher` with version `2.0.1` in LG's "system_updatable" app path (see `/etc/palm/sam-conf.json`). SAM takes the highest version per app id, so this copy wins over LG's `2.0.0` on the rootfs at the very first scan. Written by `activate.sh`. |
| `cleantv/launcher/` | Master copy of the web app: `appinfo.json` (LG Home's id and permissions, `type: web`, version 2.0.1), `index.html` (wallpaper, clock, glass tiles from `homelaunchpoints/listLaunchPoints`, launch via `applicationManager/launch`), `icons/` + `lp.js` written by `refresh.js`. |
| `/var/lib/webosbrew/init.d/10-cleantv-adblock` | Appends `config/adblock-hosts` to a bind-mounted copy of `/etc/hosts` at every boot (rootfs is read-only). |
| `/var/lib/webosbrew/init.d/30-cleantv-home` | Waits for SAM; if Home already comes from the updatable copy: verify it is in the foreground (relaunch if not), `order.sh`, `remove-preloads.sh`, relaunch so the row is re-read. Fallback: bind mount + manifest re-read. Then at +30/60/120 s `lean.sh`, `perf.sh`, close preloaded apps; afterwards every 120 s. |
| `cleantv/bin/lean.sh` | Stops systemd units, overlays respawning luna services with a sleeping stub, kills the rest; per `config/lean.conf`. `--restore` undoes it. |
| `cleantv/bin/perf.sh` | zram swap (priority 10, ahead of the eMMC swap at −2) and Mali `power_policy=always_on`; per `config/perf.conf`. |
| `cleantv/bin/settings.sh` | `settingsservice/setSystemSettings`: promotions, Live Plus, far-field voice, Always Ready, screen saver (opt-in); per `config/settings.conf`. |
| `cleantv/bin/order.sh` | `hideLaunchPoint` for `config/hidden_apps.txt`, `moveLaunchPoint` for `config/order.txt`, then icon refresh. Launch point ids are resolved from `listLaunchPoints` because HDMI inputs use numeric ids. |
| `cleantv/bin/delete-bloat.sh` | Optional: deletes LG demo content, gallery art and stale app copies from the writable partition; `--cast` also Google Cast. |

## Why a web app with LG's app id

- Everything that means "Home" on the TV (Home button via surface-manager, Back out of the last app via SAM's `last_input_handler`,
  power-on via bootManager, wake from standby) launches `com.webos.app.home`. Keeping the id means nothing else has to be patched.
- Luna service permissions are keyed by app id. As `com.webos.app.home` the web app may call `com.webos.service.homelaunchpoints/*`
  (private). As a dev-app id those calls are denied.

## Why the "system_updatable" copy beats a bind mount

- Homebrew Channel's hooks run at ~22–25 s. SAM has scanned the app folders long before (bootd launches Home at ~13 s). A bind mount
  therefore always arrives after LG Home is already on screen; the hook then has to close LG Home and launch the launcher - a race that
  produced a black screen once (cause no. 6 in TROUBLESHOOTING).
- `/media/system/apps/usr/palm/applications` is on the writable ext4 app partition and is one of SAM's scan paths (`typeByDir:
  system_updatable`). LG uses it for its own app updates (LG Channels lives there). A folder with the same id and a **higher version**
  is simply what SAM loads. Verified: `com.webos.app.browser` 11.0.0 from another path beats 9.2.3 there - the rule is "highest version".
- Result: the launcher is Home from the first second SAM knows about apps; nothing to mount, nothing to kill.

## Switching off LG services on a read-only system

- rootfs (`/`), `/usr`, `/etc` are squashfs / read-only overlays **without an upper layer** and without dm-verity. Root can do
  everything at runtime, but cannot write into the image; changing it would mean re-flashing a partition.
- Static services: `systemctl stop` (with a 10 s timeout, some units block). They stay down until reboot; the hook stops them again.
- Dynamic luna services (`Type=dynamic` in `/usr/share/luna-service2/services.d/*.service`) are respawned by `ls-hubd` whenever a client
  calls them (e.g. the analytics service `sdx`, the ThinQ link `iconnectivity`, the log uploader `uploadd`). Killing them is pointless.
  `mount --bind cleantv/stub/sleep.sh /usr/sbin/<service>` makes ls-hubd start a process that only sleeps: no CPU, no network, no
  error storm (verified 60 s each with the bus monitor). `umount` restores the real binary.
- The built-in far-field microphone shows up as ALSA capture device `WoV PDM Mic` (card 1, pcm0c). With the voice chain stopped no
  process holds it open - check with `ls -l /proc/*/fd | grep pcmC1D0c`.

## Launcher data flow

`listLaunchPoints` → filter `hidden`, drop `com.webos.app.home` → glass tile with a white SVG glyph from the `GLYPH`/`PATH` tables
(fallback: initial letter) → Left/Right/OK/Back keys, pointer hover + click → `launch {"id", "params"}` (HDMI inputs carry their
`params`). `webOSRelaunch` reloads the list, which is why the hook relaunches Home after `order.sh`.

The page is static (no network) and uses no `backdrop-filter`: blur on a dozen tiles costs the Mali-G52 real work during the focus
animation at 4K output. Semi-transparent fills look almost identical.

## Measurements that shaped the design (reference TV, 2 GB RAM)

- Idle: 90–95 % CPU idle, ~690 MB available after the clean-up (533 MB before). PSI (pressure) ≈ 0.
- App switching to foreground: Netflix 60 ms, YouTube 150 ms, IPTV web app 470 ms, launcher 50 ms.
- After opening Netflix + YouTube + an IPTV app in a row: 360 MB available, 69 MB swapped to eMMC → that is where stutter comes from.
  zram takes that swap into compressed RAM.
- Permanent CPU consumers before `lean.sh`: wake-word preprocessor ~10 % of a core, ThinQ link ~7 %, ThinQ trigger ~4 %.
- Load average of 13 is normal here: a dozen kernel driver threads sit in D state. Look at `%idle`, not at the load average.

## What does not work (so you don't try)

- Editing LG Home's layout XML can remove rows but cannot show a wallpaper or clock.
- Installing a web app *as an update* of `com.webos.app.home` through `appInstallService/dev/install` is refused - copying the folder works.
- SAM has no rescan method. `blockSystemApp` works for built-in system apps only ("this app is not system app" for updatable ones).
- `appInstallService/remove` refuses LG's system apps (`removable: false`) - delete their folders on the writable partition directly.
- Nothing can run before Homebrew Channel's `startup.sh` (~22 s); `/etc` is read-only, so no systemd units of your own.
- LG's preload manager re-launches apps from a usage model (`onModeledAppListChange`), not from `supportQuickStart`. Changing that flag
  does not stop it; closing the apps periodically does.
