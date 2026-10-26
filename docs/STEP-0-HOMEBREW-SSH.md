# Step 0: Homebrew Channel, SSH access, sideloading tools

This project needs a TV that is already rooted with **Homebrew Channel**. How to root is documented by the people who maintain
the methods; follow their README for your exact model and firmware, not blog posts or videos:

- [cani.rootmy.tv](https://cani.rootmy.tv) — which method applies to which model/firmware
- [webosbrew.org](https://www.webosbrew.org) — Homebrew Channel, repository, wiki, Discord
- Verify any "root tool" against those two pages first. Repos that ask you to install an unknown app or that are not referenced there
  cost us an evening on the reference TV.

Everything below is plain device administration and was done on an LG C3 (webOS 11.2, October 2026).

## Checking whether the TV can be rooted, then rooting (how we do it for a second TV)

**Step 1, checking whether the TV can be rooted:**

1. On the TV: Settings, All Settings, Support, then "About This TV" or "Software Info". There you find the model number and the webOS
   software version, for example `11.2.0-3701` as on the reference C3.
2. On your computer or phone, open [cani.rootmy.tv](https://cani.rootmy.tv). Enter the model and software version or look them up in the
   table. The page tells you whether and with which method this version can be rooted, and links directly to that method.
3. Compare with the first TV: if the second one is on the same version, the same method applies. If it is newer, only what
   cani.rootmy.tv says about that newer version counts. Above all, in that case: stop allowing system updates on the second TV
   (Settings → Support → Software Update → automatic updates off) until it is clear whether the version remains rootable.

**Step 2, the rooting itself,** follows the instructions of the tool that worked on the first TV. The link is in the [README](../README.md)
under Requirements. In practice this means: open that project's README on GitHub, work through its prerequisites, computer and TV on the
same network, TV IP address noted, and then carry out its steps in the given order.

## What the root method leaves you with

On the reference TV the rooting tool installed **Homebrew Channel** (0.7.3) itself; no separate install was needed. Its README told
us to **remove LG's Developer Mode app before the first reboot** — skipping that would have lost root. Follow your method's README
for such details, they differ per tool. After the reboot, Homebrew Channel showed *Root status: ok*.

Homebrew Channel also brings the mechanism this project relies on: at boot it runs every executable file in
`/var/lib/webosbrew/init.d/` (via `run-parts`). If a hook crashes the boot, Homebrew Channel starts in **failsafe mode**
(root customizations disabled once, a toast tells you) — that is your safety net while experimenting.

## Homebrew Channel settings (do this right after rooting)

Open Homebrew Channel → Settings:

- **Root status** must read *ok*.
- **Block system updates: on** — an LG firmware update would remove root and this project with it.
- **SSH server: on** (use SSH, not Telnet). Default password is documented by Homebrew Channel (`alpine`); change it or use a key.
- Reboot once and check Root status again.

## SSH from your computer

```bash
ssh-keygen -t ed25519 -f ~/.ssh/webos_tv_root -N ''      # once
ssh-copy-id -i ~/.ssh/webos_tv_root.pub root@<tv-ip>       # enter the Homebrew Channel SSH password once
ssh -i ~/.ssh/webos_tv_root root@<tv-ip> 'uname -r; cat /var/run/nyx/os_info.json | head'
```

Useful habits learned on the way:

- `luna-send` prints nothing over a non-interactive SSH session unless you pass `-f`; `ssh -tt` also works.
- Every hook you put in `/var/lib/webosbrew/init.d` runs at boot — never leave `.bak` copies there (see TROUBLESHOOTING.md).
- The TV's `node` lives at `/usr/bin/node`; `python3` is not available on the TV.

## Installing apps (IPK) with root

With root you do not need LG's Developer Mode app at all. Copy the IPK and ask the installer service:

```bash
scp -i ~/.ssh/webos_tv_root some-app.ipk root@<tv-ip>:/tmp/
ssh -tt -i ~/.ssh/webos_tv_root root@<tv-ip> \
  "luna-send -i -f luna://com.webos.appInstallService/dev/install '{\"id\":\"<app id>\",\"ipkUrl\":\"/tmp/some-app.ipk\",\"subscribe\":true}'"
```

Watch for `"state": "installed"`, then Ctrl-C. Homebrew Channel can also install from its repository UI.

## Without root: LG Developer Mode + ares-cli (optional)

If you only want to sideload apps without rooting, LG's official way is the Developer Mode app plus `@webosose/ares-cli`
(`npm i -g @webosose/ares-cli`, `ares-setup-device`, `ares-install`). Two traps we hit on current firmware and Node 26:

1. **`Permission denied` on `/media/developer/temp`:** the Developer Mode user may only create the sub-folder. In
   `node_modules/@webosose/ares-cli/files/conf/config.json` set `install.tempDirForIpk` to `/media/developer/temp/ares`.
2. **`TypeError: isDate is not a function`:** `ssh2-streams/lib/sftp.js` uses `util.isDate`, removed in Node 23+. Replace it with
   `util.types.isDate` (or run ares-cli with Node 22). Both patches live inside the global ares-cli install and vanish with its next update.

Developer Mode is not needed once the TV is rooted, and some rooting tools require it to be uninstalled before the first reboot — again, follow the method's README.
