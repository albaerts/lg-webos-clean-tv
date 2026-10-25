#!/bin/sh
# refresh.sh - refresh launcher icons + fallback list. Safe to run anytime (e.g. after installing an app).
. /var/lib/webosbrew/cleantv/bin/common.sh
J=/tmp/cleantv_lp.json
ls2 $LP/listLaunchPoints '{}' > $J
[ -s $J ] || { log "no launch point data"; exit 0; }
/usr/bin/node $CT/bin/refresh.js $J $APP
