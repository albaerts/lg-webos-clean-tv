#!/bin/sh
# activate.sh - make the launcher the Home app, persistently and at runtime, without restarting SAM.
# Method (webOS 11, verified 2026-10): copy the launcher to the "system_updatable" app path with a HIGHER version than LG Home.
# SAM takes the highest version of an app id when it scans at boot -> bootd opens OUR launcher at ~13 s directly: no LG Home,
# no bind mount, no race. Fallback (if SAM does not take the copy): bind-mount over LG Home + block/release re-read.
. /var/lib/webosbrew/cleantv/bin/common.sh
lgver=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' $HOME_T/appinfo.json 2>/dev/null | head -1)
ourver=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' $APP/appinfo.json | head -1)
log "LG Home version $lgver, launcher version $ourver (ours must be higher; edit launcher/appinfo.json if not)"
mkdir -p "$(dirname $UPD)"
rm -rf $UPD; cp -a $APP $UPD; chown -R root:root $UPD
sh $CT/bin/refresh.sh >/dev/null 2>&1
reread_app com.webos.app.home
k=0; while [ $k -lt 30 ]; do [ "$(home_folder)" = "$UPD" ] && [ "$(home_type)" = web ] && break; sleep 1; k=$((k+1)); done
if [ "$(home_folder)" = "$UPD" ] && [ "$(home_type)" = web ]; then
  log "SAM takes the launcher from $UPD (system_updatable) - persistent across reboots"
else
  log "SAM kept $(home_folder) type=$(home_type) - falling back to bind mount (hook re-applies it at boot)"
  rm -rf $UPD
  home_mounted || mount --bind $APP $HOME_T
  reread_app com.webos.app.home
  k=0; while [ $k -lt 30 ]; do [ "$(home_type)" = web ] && break; sleep 1; k=$((k+1)); done
  [ "$(home_type)" = web ] || { log "SAM did not take the launcher manifest (type=$(home_type)) - rolling back"; umount $HOME_T 2>/dev/null; reread_app com.webos.app.home; exit 1; }
fi
close_lg_home
sh $CT/bin/order.sh >/dev/null 2>&1
reload_home && log "launcher is Home (SAM pid $(pidof sam) unchanged)" || log "launcher did not reach the foreground - see docs/TROUBLESHOOTING.md"
