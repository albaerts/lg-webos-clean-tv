#!/bin/sh
# common.sh - shared helpers for lg-webos-clean-tv (sourced by the other scripts)
CT=/var/lib/webosbrew/cleantv
APP=$CT/launcher
CFG=$CT/config
HOME_T=/usr/palm/applications/com.webos.app.home
L=luna://com.webos.applicationManager
LP=luna://com.webos.service.homelaunchpoints
ls2() { timeout 8 luna-send -n 1 -f "$@" 2>/dev/null; }
log() { echo "$(date '+%F %T') $*"; }
sam_ok() { ls2 $L/getForegroundAppInfo '{}' | grep -q returnValue; }
home_type() { ls2 $L/getAppInfo '{"id":"com.webos.app.home"}' | sed -n 's/.*"type": *"\([^"]*\)".*/\1/p' | head -1; }
home_mounted() { grep -q " $HOME_T " /proc/mounts; }
lg_home_pids() { for p in /proc/[0-9]*; do c=$(tr '\0' ' ' < $p/cmdline 2>/dev/null); case "$c" in /usr/bin/flutter-client*com.webos.app.home*|/usr/bin/com.webos.app.home*) echo ${p#/proc/};; esac; done; }
# SAM re-reads one app's appinfo.json after block + release (no SAM restart). webOS 11 needs forceBlockSystemApp.
reread_app() {
  force=; grep -q '"forceBlockSystemApp"' /etc/palm/schemas/sam/applicationManager.blockSystemApp.schema 2>/dev/null && force=',"forceBlockSystemApp":false'
  ls2 $L/blockSystemApp "{\"id\":\"$1\"$force}" | grep -q '"returnValue": *true'; b=$?
  for _ in 1 2 3; do ls2 $L/releaseBlockSystemApp "{\"id\":\"$1\"}" | grep -q '"returnValue": *true' && return $b; sleep 1; done
  return 1
}
