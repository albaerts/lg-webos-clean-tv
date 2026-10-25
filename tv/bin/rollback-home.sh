#!/bin/sh
# rollback-home.sh - restore LG's stock Home now (runtime), no SAM restart. Add --permanent to also disable the boot hook.
. /var/lib/webosbrew/cleantv/bin/common.sh
while home_mounted; do umount $HOME_T 2>/dev/null || umount -l $HOME_T 2>/dev/null || break; done
reread_app com.webos.app.home
sleep 2; log "SAM type now: $(home_type) (expected: flutter or qml)"
ls2 luna://com.palm.webappmanager/killApp '{"appId":"com.webos.app.home"}' >/dev/null
ls2 $L/launch '{"id":"com.webos.app.home"}' >/dev/null
if [ "$1" = "--permanent" ]; then mkdir -p /var/lib/webosbrew/off; mv /var/lib/webosbrew/init.d/30-cleantv-home /var/lib/webosbrew/off/ 2>/dev/null && log "boot hook disabled (moved to /var/lib/webosbrew/off/)"; fi
log "stock LG Home restored"
