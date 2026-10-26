# lg-webos-clean-tv

A clean LG webOS TV: **your own minimal Home screen** (wallpaper, clock, one row of glass tiles) that **comes up directly after
power-on**, **no ad banner, no sponsored rows, no "Live on LG Channels"**, **LG ad / telemetry / ThinQ hosts blocked**, **voice
microphones, ThinQ cloud link and LG data collection switched off**, promotions off, less swapping. Reversible in one command.

Tested end to end on an **LG OLED77C37LA (C3, 2023), webOS 11.2.0-3701 ("webOS 26"), October 2026**, rooted with Homebrew Channel,
verified with ten protocolled reboots. Other models and firmware versions will differ. Read the whole page before you start.

![before / after](docs/before-after.png)

## What you get

| Before | After |
|---|---|
| Hero banner, Edit card, app row, Recent input, "Live on LG Channels", "Trending now", sponsored rows | Wallpaper, clock, one row of uniform glass tiles with exactly the apps you want |
| Last input (HDMI) for ~15 s after power-on, then LG Home | **Your launcher at ~20 s, nothing else before it** (LG's boot manager starts it itself) |
| Ad, telemetry, ACR, ThinQ beacons to lgsmartad.com, cdpbeacon/rdx2/lgtviot/… | Blocked in `/etc/hosts` at every boot (39 hosts) |
| Built-in wake-word microphone and remote microphone always processing (10 % of a core) | Voice chain stopped; no process holds the microphone device |
| ThinQ cloud link, analytics upload (sdx), log upload, nudges, fitness/wearable services, Alexa trigger | Stopped; respawning services overlaid with a sleeping stub |
| Netflix/YouTube/Browser/LG Channels resident, swap on flash | Unused preloads closed; compressed RAM swap (zram) ahead of flash; GPU kept awake |
| Home promotion, Live Plus (ACR), Always Ready, UI transparency | Off via LG's own settings service (persist, no hacks) |

Nothing on the read-only system partitions is modified (they are squashfs images - even root cannot write there). Everything lives in
`/var/lib/webosbrew/cleantv` plus one launcher copy in LG's writable "updatable apps" folder, and is applied at boot by two Homebrew
Channel init.d hooks. `uninstall.sh` puts LG's Home and services back.

## The whole path, in order

| # | Step | Where |
|---|---|---|
| 0 | Check rootability on cani.rootmy.tv, root the TV following the tool's README, Homebrew Channel: Root status ok, **Block system updates**, **SSH server** on, SSH key | [docs/STEP-0-HOMEBREW-SSH.md](docs/STEP-0-HOMEBREW-SSH.md) |
| 1 | Review `config/*.conf` (what to switch off) and `config/order.txt` / `hidden_apps.txt`; copy the repo to the TV, run `tv/install.sh` | *Install* below |
| 2 | Press Home: the launcher is there. Adjust row, wallpaper, glyphs; run `order.sh` / `activate.sh` | *Customize* below |
| 3 | Reboot once and watch: launcher at ~20 s, no LG Home, no HDMI first; read `log/boot.log` | *Boot behaviour* below |
| 4 | Optional, destructive: delete LG payload from the writable partition (demo content, gallery art, Google Cast) | `delete-bloat.sh` below |
| 5 | Optional: IPTV player | [docs/IPTV.md](docs/IPTV.md) |
| 6 | If anything looks wrong: rollback in one command, read the boot log | *Rollback*, [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) |

## Requirements

1. A **rooted** LG webOS TV with **Homebrew Channel** and **SSH** enabled. Root instructions and the "can I root my TV" table live at
   [cani.rootmy.tv](https://cani.rootmy.tv) and [webosbrew.org](https://www.webosbrew.org). For 2023–2026 firmware the working
   userspace exploit at the time of writing was [throwaway96/slopbro](https://github.com/throwaway96/slopbro).
2. In Homebrew Channel: **Block system updates** on (an LG update would otherwise remove root and this project), **SSH server** on.
3. A computer with `ssh`/`scp`. Default root password of Homebrew Channel's SSH server is `alpine` — change it or use a key.
4. `/usr/bin/node` on the TV (present on webOS 5+; used for icons and launch point ids).

**Not rooted yet?** Start with [docs/STEP-0-HOMEBREW-SSH.md](docs/STEP-0-HOMEBREW-SSH.md).

## Install (10 minutes)

```bash
# on your computer, from this repository
scp -r . root@<tv-ip>:/tmp/cleantv
ssh root@<tv-ip> 'sh /tmp/cleantv/tv/install.sh'
```

`install.sh` copies scripts and config to `/var/lib/webosbrew/cleantv`, installs the two boot hooks, applies the settings switches,
blocks the hosts for this boot, **installs the launcher as a higher-versioned copy of LG Home** (`activate.sh`), stops the LG features
listed in `config/lean.conf` and applies `config/perf.conf` — all at runtime, without rebooting or restarting any LG service.
Press **Home**: you should see the new launcher.

### What the switches mean (read before installing)

| File | Switch | Effect when on | Costs you |
|---|---|---|---|
| `config/lean.conf` | `VOICE_OFF=1` | built-in wake-word mic and remote mic processing stopped | the microphone button on the remote |
| | `THINQ_OFF=1` | ThinQ/IoT cloud link, Matter client, zigbee hub stopped | ThinQ app remote control |
| | `TELEMETRY_OFF=1` | analytics (sdx), log upload, nudges, fitness/wearables, Alexa trigger stopped | nothing you use |
| | `CAST_OFF=0` | Google Cast provisioning (set after `delete-bloat.sh --cast`) | casting from Android/Chrome |
| `config/settings.conf` | `LIVEPLUS_OFF=1` | Live Plus / ACR content recognition off | nothing |
| | `VOICE_FARFIELD_OFF=1`, `ALWAYS_READY_OFF=1` | wake-word setting off; power off means off | Always Ready art mode |
| | `SCREENSAVER_OFF=0` | **leave at 0 on an OLED** unless you accept the burn-in risk of a static launcher | |
| `config/perf.conf` | `ZRAM_MB=512`, `GPU_ALWAYS_ON=1` | compressed swap in RAM, GPU never power-gated | a little power |

AirPlay is not touched (it cannot be deleted; stop `airplay*` services yourself if you never use it).

### Customize (on the TV, as root; `C=/var/lib/webosbrew/cleantv`)

| What | How |
|---|---|
| Hide tiles | edit `$C/config/hidden_apps.txt`, run `sh $C/bin/order.sh` |
| Row order | edit `$C/config/order.txt`, run `order.sh`. HDMI inputs work too (their ids are resolved) |
| Wallpaper, look | edit `$C/launcher/wallpaper.jpg` (1920×1080 JPEG) / `index.html`, then `sh $C/bin/activate.sh` (copies to the live folder and reloads) |
| Tile glyph for a new app | add its app id to the `GLYPH` table in `index.html` (SVG path or `TEXT:name`); unknown apps show their initial |
| Apps LG keeps preloading | `$C/config/close_preloads.txt` |
| Remove store preloads at boot | `$C/config/remove_apps.txt` (removable apps only) |
| Blocked hosts | `$C/config/adblock-hosts` |

Find app ids with `luna-send -n 1 -f luna://com.webos.service.homelaunchpoints/listLaunchPoints '{}'`.

### delete-bloat.sh (optional, destructive)

Only the **writable** app partition can be cleaned; LG's system apps on the read-only rootfs can be hidden and stopped but never deleted.

```bash
ssh root@<tv-ip> 'sh /var/lib/webosbrew/cleantv/bin/delete-bloat.sh --yes'          # store demo content ~1.2 GB, gallery art ~0.5 GB, stale app copies
ssh root@<tv-ip> 'sh /var/lib/webosbrew/cleantv/bin/delete-bloat.sh --yes --cast'   # additionally Google Cast (apps + services). Comes back only with an LG update.
```

Uninstall Homebrew/dev apps you no longer need with `luna-send -n 1 -f luna://com.webos.appInstallService/remove '{"id":"<app id>"}'`.

## Rollback

```bash
ssh root@<tv-ip> 'sh /var/lib/webosbrew/cleantv/bin/rollback-home.sh --permanent'   # LG Home back, hook off
ssh root@<tv-ip> 'sh /var/lib/webosbrew/cleantv/bin/lean.sh --restore'              # LG services back (voice, ThinQ, telemetry)
ssh root@<tv-ip> 'sh /tmp/cleantv/tv/uninstall.sh'                                   # everything off, tiles unhidden
```

All work at runtime. Settings switches are LG's own settings; turn them back on in the TV menu if you miss them. `/etc/hosts` block and
zram end at the next reboot once the hooks are gone.

## How it works (short)

- Everything that means "Home" (Home button, back out of the last app, power-on) launches `com.webos.app.home`. The launcher is a plain
  **web app with that id**, so it inherits Home's permissions and needs no patching elsewhere.
- **Direct start:** SAM (the app manager) scans several app folders at boot and, for one app id, takes the **highest version**. The
  launcher is copied to the writable `/media/system/apps/usr/palm/applications/com.webos.app.home` as version `2.0.1`; LG's is `2.0.0`.
  bootd therefore opens the launcher itself at ~13 s. No bind mount, no kill, no race. (Fallback: bind mount + `blockSystemApp`/
  `releaseBlockSystemApp` manifest re-read, the method from [rorygallagher2024/glasshouse](https://github.com/rorygallagher2024/glasshouse).)
- **Switching LG features off on a read-only system:** systemd units are stopped; luna services that ls-hubd respawns on every call get
  their binary **overlaid with a sleeping stub** (`mount --bind`). The hub then only ever starts `sleep`. Same effect as deleting, reversible.
- Tiles are hidden with the official `homelaunchpoints/hideLaunchPoint`; order with `moveLaunchPoint` (HDMI inputs have numeric ids).
- Icons are white SVG glyphs per app id; LG's PNG icons are copied into the launcher folder as fallback material by `refresh.sh`.

Details: [docs/HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md). Things that went wrong and why: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

## Boot behaviour (reference TV)

| time | what |
|---|---|
| 13 s | bootd launches `com.webos.app.home` = the launcher (SAM picked the 2.0.1 copy) |
| 20 s | launcher visible |
| 25 s | hook: verifies foreground, applies row order, remove-preloads, relaunch so the row is current |
| +30/60/120 s | `lean.sh`, `perf.sh`, close preloaded apps; then every 2 minutes |

Measured app switching after this: Netflix/YouTube/launcher 60–150 ms to foreground. What remains slow is hardware and LG UI: the HDMI
handshake with a console (1–2 s black) and LG's own Flutter menus on the 4K compositor.

## Not included on purpose

- No IPTV provider, playlist or credentials. See [docs/IPTV.md](docs/IPTV.md).
- No changes to the read-only system image (would need re-flashing a partition; brick risk, no benefit over "never runs").
- No third-party wallpaper artwork; the default is a generated gradient.

## Credits

Glasshouse (SAM re-read, home takeover), lg-luma (home.sh pattern), webosbrew.org (Homebrew Channel, init.d hooks),
furkan-bayrak/lg-tv-blocklist (ad host list), simple-icons (brand glyphs), throwaway96 (SlopBro).

## License

MIT. Use at your own risk; this modifies a rooted TV.
