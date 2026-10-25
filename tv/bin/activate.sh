#!/bin/sh
# activate.sh - make the launcher the Home app NOW (runtime), without restarting SAM.
# 1) bind-mount launcher dir over LG Home, 2) SAM re-reads the manifest (block/release), 3) stop LG Home process, 4) open launcher.
. /var/lib/webosbrew/cleantv/bin/common.sh
home_mounted || mount --bind $APP $HOME_T
sh $CT/bin/refresh.sh >/dev/null 2>&1
reread_app com.webos.app.home
k=0; while [ $k -lt 30 ]; do [ "$(home_type)" = "web" ] && break; sleep 1; k=$((k+1)); done
if [ "$(home_type)" != "web" ]; then log "SAM did not take the launcher manifest (type=$(home_type)) - rolling back mount"; umount $HOME_T 2>/dev/null; reread_app com.webos.app.home; exit 1; fi
for p in $(lg_home_pids); do kill $p 2>/dev/null; done
sh $CT/bin/order.sh >/dev/null 2>&1
ls2 $L/launch '{"id":"com.webos.app.home"}' >/dev/null
log "launcher is Home (SAM type=web, pid $(pidof sam) unchanged)"
