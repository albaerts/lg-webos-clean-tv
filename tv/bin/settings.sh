#!/bin/sh
# settings.sh - LG's own settings service switches (persist across reboots, no root hacks). Config: config/settings.conf
. /var/lib/webosbrew/cleantv/bin/common.sh
LIVEPLUS_OFF=1; VOICE_FARFIELD_OFF=1; ALWAYS_READY_OFF=1; SCREENSAVER_OFF=0
[ -f $CFG/settings.conf ] && . $CFG/settings.conf
set_opt() { ls2 luna://com.webos.settingsservice/setSystemSettings "{\"category\":\"$1\",\"settings\":$2}" | grep -q '"returnValue": *true' && log "ok  $1 $2" || log "FAIL $1 $2"; }
# promotions, suggestions, "Live on LG Channels", UI transparency (always)
set_opt general '{"homePromotion":"off"}'
set_opt option  '{"livePromotion":"off","webOSPromotionVideo":"off","animationGuide":"off","watchedListCollection":"off"}'
set_opt option  '{"channelplus":"off","lgChannelAutoStart":"off"}'
set_opt option  '{"menuTransparency":"off"}'
[ "$LIVEPLUS_OFF" = 1 ]      && set_opt option  '{"livePlus":"off"}'                       # ACR content recognition
[ "$VOICE_FARFIELD_OFF" = 1 ] && set_opt general '{"voiceLongDistance":"off"}'              # built-in wake-word microphone
[ "$ALWAYS_READY_OFF" = 1 ]  && set_opt general '{"lifeOnScreenMode":"none"}'              # "Always Ready": off means off
[ "$SCREENSAVER_OFF" = 1 ]   && set_opt general '{"screenSaverEnabled":"off","screenSaverAd":"off"}'   # OLED burn-in protection! default stays on
