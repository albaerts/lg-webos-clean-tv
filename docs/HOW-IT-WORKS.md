# How it works

## Pieces

| Path on TV | Purpose |
|---|---|
| `/var/lib/webosbrew/init.d/10-cleantv-adblock` | Appends `config/adblock-hosts` to a bind-mounted copy of `/etc/hosts` at every boot (rootfs is read-only). |
| `/var/lib/webosbrew/init.d/30-cleantv-home` | Waits for sam, bind-mounts the launcher over `/usr/palm/applications/com.webos.app.home` (retry until the ~35 s partition remount is over), block/release so sam re-reads the manifest, kills the LG Home process, opens the launcher, applies `order.sh` and `remove-preloads.sh`, sweeps stray LG Home processes at +30/+60/+120 s. |
| `cleantv/launcher/` | The web app: `appinfo.json` with LG Home's id and permissions (`type: web`), `index.html` (wallpaper, clock, app row from `homelaunchpoints/listLaunchPoints`, launch via `applicationManager/launch`), `icons/` + `lp.js` written by `refresh.js`. |
| `cleantv/bin/settings.sh` | `settingsservice/setSystemSettings`: `general/homePromotion`, `option/livePromotion`, `webOSPromotionVideo`, `animationGuide`, `watchedListCollection`, `channelplus`, `lgChannelAutoStart`, `menuTransparency` → off. Persist in LG's settings DB. |
| `cleantv/bin/order.sh` | `hideLaunchPoint` for `config/hidden_apps.txt`, `moveLaunchPoint` for `config/order.txt`, then icon refresh. Order does not always survive a forced reboot, so the hook re-applies it. |

## Why a web app with LG's app id

- Everything that means "Home" on the TV (Home button via surface-manager, Back out of the last app via sam's `last_input_handler`,
  wake from standby via bootManager) launches `com.webos.app.home`. Keeping the id means nothing else has to be patched.
- Luna service permissions are keyed by app id. As `com.webos.app.home` the web app may call `com.webos.service.homelaunchpoints/*`
  (private). As a dev-app id those calls are denied.
- The directory bind mount is the only change; LG's files stay underneath. The remount of the app partitions ~35 s after boot drops
  bind mounts, hence the retry loop.

## What does not work (so you don't try)

- Editing LG Home's layout XML (`data/flutter_assets/assets/home.xml`) can remove rows (banner, shelves) but the page attributes
  `background`/`bgImage`/`image` are ignored and the `clock`/`wallpaper` items render nothing on the normal page. Black background only.
- Installing a web app *as an update* of `com.webos.app.home` through `appInstallService/dev/install` is refused.
- sam has no rescan method (full list in `/usr/share/luna-service2/api-permissions.d/com.webos.sam.api.json`).
- Nothing can run before Homebrew Channel's `startup.sh` (~22 s); `/etc` is a read-only overlay, so no systemd units.

## Launcher data flow

`listLaunchPoints` → filter `hidden`, drop `com.webos.app.home` → tiles with `icons/<id>.<ext>` (fallback: first letter on `bgColor`) →
Left/Right/OK/Back keys, pointer hover + click → `launch {"id", "params"}` (HDMI inputs carry their `params`). `webOSRelaunch` reloads the list.
