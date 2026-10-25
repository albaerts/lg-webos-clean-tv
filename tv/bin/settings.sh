#!/bin/sh
# settings.sh - official settingsservice switches that remove promotions/suggestions from LG Home (persist across reboots, no root hacks).
. /var/lib/webosbrew/cleantv/bin/common.sh
set_opt() { ls2 luna://com.webos.settingsservice/setSystemSettings "{\"category\":\"$1\",\"settings\":$2}" | grep -q '"returnValue": *true' && log "ok  $1 $2" || log "FAIL $1 $2"; }
set_opt general '{"homePromotion":"off"}'
set_opt option  '{"livePromotion":"off","webOSPromotionVideo":"off","animationGuide":"off","watchedListCollection":"off"}'
set_opt option  '{"channelplus":"off","lgChannelAutoStart":"off"}'
set_opt option  '{"menuTransparency":"off"}'
