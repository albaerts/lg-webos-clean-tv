#!/bin/sh
# refresh.sh - refresh launcher icons + fallback list. Safe to run anytime (e.g. after installing an app).
# Writes into the live launcher copy (system_updatable path) when it exists, else into the master copy.
. /var/lib/webosbrew/cleantv/bin/common.sh
J=/tmp/cleantv_lp.json; T=$APP; [ -f $UPD/appinfo.json ] && T=$UPD
ls2 $LP/listLaunchPoints '{}' > $J
[ -s $J ] || { log "no launch point data"; exit 0; }
/usr/bin/node $CT/bin/refresh.js $J $T
