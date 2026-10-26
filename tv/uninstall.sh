#!/bin/sh
# uninstall.sh - run ON THE TV as root. Restores LG Home, re-enables LG services, removes hooks, unhides tiles. Settings switches stay (LG menu).
. /var/lib/webosbrew/cleantv/bin/common.sh 2>/dev/null || { echo "not installed"; exit 0; }
sh $CT/bin/rollback-home.sh --permanent
sh $CT/bin/lean.sh --restore
for a in $(strip $CFG/hidden_apps.txt); do ls2 $LP/unhideLaunchPoint "{\"launchPointId\":\"$(lpid $a)\"}" >/dev/null; done
rm -f /var/lib/webosbrew/init.d/10-cleantv-adblock /var/lib/webosbrew/init.d/30-cleantv-home
echo "hooks removed, tiles unhidden, LG Home and LG services restored. /etc/hosts block and zram end at next reboot. Files kept in $CT (delete manually)."
