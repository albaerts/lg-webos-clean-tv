# Step 0: Homebrew Channel, SSH access, sideloading tools

This project needs a TV that is already rooted with **Homebrew Channel**. How to root is documented by the people who maintain
the methods; follow their README for your exact model and firmware, not blog posts or videos:

- [cani.rootmy.tv](https://cani.rootmy.tv) — which method applies to which model/firmware
- [webosbrew.org](https://www.webosbrew.org) — Homebrew Channel, repository, wiki, Discord
- Verify any "root tool" against those two pages first. Repos that ask you to install an unknown app or that are not referenced there
  cost us an evening on the reference TV.

Everything below is plain device administration and was done on an LG C3 (webOS 11.2, October 2026).

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
