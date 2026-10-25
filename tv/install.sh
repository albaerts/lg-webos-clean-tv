#!/bin/sh
# install.sh - run ON THE TV as root from the unpacked repo directory:  sh tv/install.sh
# Installs scripts, config, launcher and boot hooks under /var/lib/webosbrew, applies settings, activates the launcher now.
set -e
[ "$(id -u)" = 0 ] || { echo "run as root"; exit 1; }
[ -d /var/lib/webosbrew/init.d ] || { echo "Homebrew Channel init.d not found - root with Homebrew Channel is required"; exit 1; }
[ -x /usr/bin/node ] || { echo "/usr/bin/node missing - this firmware is not supported by the icon refresh"; exit 1; }
SRC=$(cd "$(dirname "$0")/.." && pwd)
CT=/var/lib/webosbrew/cleantv
mkdir -p $CT/bin $CT/config $CT/launcher $CT/log /var/lib/webosbrew/off
cp $SRC/tv/bin/*.sh $SRC/tv/bin/*.js $CT/bin/; chmod +x $CT/bin/*.sh
for f in hidden_apps.txt order.txt remove_apps.txt adblock-hosts; do [ -f $CT/config/$f ] || cp $SRC/config/$f $CT/config/$f; done
cp -r $SRC/launcher/app/. $CT/launcher/
cp $SRC/tv/hooks/10-cleantv-adblock /var/lib/webosbrew/init.d/10-cleantv-adblock
cp $SRC/tv/hooks/30-cleantv-home   /var/lib/webosbrew/init.d/30-cleantv-home
chmod +x /var/lib/webosbrew/init.d/10-cleantv-adblock /var/lib/webosbrew/init.d/30-cleantv-home
echo "files installed under $CT and /var/lib/webosbrew/init.d"
sh $CT/bin/settings.sh
sh /var/lib/webosbrew/init.d/10-cleantv-adblock && echo "ad/telemetry hosts blocked (this boot)"
sh $CT/bin/activate.sh
echo "done. Config: $CT/config/*  Wallpaper: $CT/launcher/wallpaper.jpg (1920x1080 JPEG)  Log: $CT/log/boot.log"
echo "Rollback: sh $CT/bin/rollback-home.sh --permanent   Full uninstall: sh tv/uninstall.sh"
