#!/bin/sh
# remove-preloads.sh - remove store-preloaded apps listed in config/remove_apps.txt (removable apps only). Called by boot hook.
. /var/lib/webosbrew/cleantv/bin/common.sh
for a in $(sed -e 's/#.*$//' -e '/^[[:space:]]*$/d' -e 's/\r$//' $CFG/remove_apps.txt 2>/dev/null); do
  ls2 luna://com.webos.appInstallService/remove "{\"id\":\"$a\"}" >/dev/null && log "remove requested: $a"
done
