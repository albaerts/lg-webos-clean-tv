#!/bin/sh
# uninstall.sh - run ON THE TV as root. Restores LG Home, removes hooks, unhides tiles, keeps settings switches (undo manually if wanted).
. /var/lib/webosbrew/cleantv/bin/common.sh 2>/dev/null || { echo "not installed"; exit 0; }
sh $CT/bin/rollback-home.sh --permanent
for a in $(sed -e 's/#.*$//' -e '/^[[:space:]]*$/d' $CFG/hidden_apps.txt 2>/dev/null); do ls2 $LP/unhideLaunchPoint "{\"launchPointId\":\"${a}_default\"}" >/dev/null; done
rm -f /var/lib/webosbrew/init.d/10-cleantv-adblock /var/lib/webosbrew/init.d/30-cleantv-home
echo "hooks removed, tiles unhidden, LG Home restored. /etc/hosts block ends at next reboot. Files kept in $CT (delete manually)."
