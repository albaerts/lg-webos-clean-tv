#!/bin/sh
# order.sh - apply desired app row: hide tiles listed in config/hidden_apps.txt, order per config/order.txt. Idempotent.
. /var/lib/webosbrew/cleantv/bin/common.sh
strip() { sed -e 's/#.*$//' -e 's/[[:space:]]*$//' -e '/^$/d' -e 's/\r$//' "$1" 2>/dev/null; }
for a in $(strip $CFG/hidden_apps.txt); do ls2 $LP/hideLaunchPoint "{\"launchPointId\":\"${a}_default\"}" >/dev/null; done
i=0; for a in $(strip $CFG/order.txt); do ls2 $LP/moveLaunchPoint "{\"launchPointId\":\"${a}_default\",\"position\":$i}" >/dev/null; i=$((i+1)); done
sh $CT/bin/refresh.sh >/dev/null 2>&1
ls2 $LP/listLaunchPoints '{}' > /tmp/cleantv_lp.json
/usr/bin/node -e 'var j=JSON.parse(require("fs").readFileSync("/tmp/cleantv_lp.json","utf8"));console.log("row: "+j.launchPoints.map(function(l){return l.title}).join(" | "))' 2>/dev/null
