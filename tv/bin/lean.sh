#!/bin/sh
# lean.sh - switch off LG background features you do not use: voice (built-in wake-word mic + remote mic), ThinQ/IoT cloud link,
# LG data collection (analytics, log upload, nudges, fitness, Alexa trigger), Google Cast provisioning. Called by the boot hook; run anytime.
# Everything is reversible: sh lean.sh --restore. Nothing on the read-only rootfs is modified.
# Techniques: systemd units are stopped; dynamic luna services (respawned by ls-hubd on every call) get their binary overlaid with a
# sleeping stub via bind mount -> ls-hubd only ever starts "sleep": no process, no upload, no respawn storm. Config: config/lean.conf
. /var/lib/webosbrew/cleantv/bin/common.sh
VOICE_OFF=1; THINQ_OFF=1; TELEMETRY_OFF=1; CAST_OFF=0
[ -f $CFG/lean.conf ] && . $CFG/lean.conf
STUB=$CT/stub/sleep.sh
UNITS=""; PROCS=""; STUBS=""
[ "$VOICE_OFF" = 1 ]     && { UNITS="$UNITS voiceconductor.service voiceinput.service wowplay.service"; PROCS="$PROCS trigger_thinq voiceinput_prep voiceinput_soun voiceinput_hidr voiceclick"; }
[ "$THINQ_OFF" = 1 ]     && { UNITS="$UNITS com.webos.service.zigbeeadapter.service iot-client.service"; PROCS="$PROCS lg.thinqai.adap iot-client"; STUBS="$STUBS /usr/sbin/iconnectivity"; }
[ "$TELEMETRY_OFF" = 1 ] && { UNITS="$UNITS nudge.service user-context-manager.service uploadd.service ftms.service fitnessxiaomiwear.service"; PROCS="$PROCS nudge user-context-ma trigger_alexa ftms fitnessxiaomiwe"; STUBS="$STUBS /usr/sbin/sdx /usr/sbin/uploadd"; }
[ "$CAST_OFF" = 1 ]      && { UNITS="$UNITS chromecast-provisioning.service"; PROCS="$PROCS com.webos.chrom chromecast-prov"; }
if [ "$1" = "--restore" ]; then
  for b in /usr/sbin/sdx /usr/sbin/uploadd /usr/sbin/iconnectivity; do umount $b 2>/dev/null; done; pkill -f "sleep 2147483647" 2>/dev/null
  systemctl start voiceconductor.service voiceinput.service wowplay.service com.webos.service.zigbeeadapter.service iot-client.service nudge.service user-context-manager.service uploadd.service chromecast-provisioning.service 2>/dev/null
  log "restored: units started, stubs removed (dynamic services return when something calls them)"; exit 0
fi
for u in $UNITS; do systemctl is-active --quiet $u && timeout 10 systemctl stop $u 2>/dev/null; done
[ -x $STUB ] || { mkdir -p ${STUB%/*}; printf '#!/bin/sh\nexec sleep 2147483647\n' > $STUB; chmod 755 $STUB; }
for b in $STUBS; do [ -f $b ] && { grep -q " $b " /proc/mounts || mount --bind $STUB $b 2>/dev/null; }; done
for n in $PROCS; do pkill -x $n 2>/dev/null; done
for p in $(pgrep -f '^/usr/palm/services/com.webos.iotframework/com.webos.iotframework'); do [ "$THINQ_OFF" = 1 ] && kill $p 2>/dev/null; done
for n in sdx uploadd iconnectivity; do echo "$STUBS" | grep -q "/$n" && for p in $(pgrep -x $n); do kill -9 $p 2>/dev/null; done; done
[ "$1" = "-v" ] && for n in voiceinput_prep trigger_thinq iconnectivity sdx uploadd nudge trigger_alexa iot-client; do pgrep -x $n >/dev/null && echo "running: $n" || echo "gone: $n"; done
exit 0
