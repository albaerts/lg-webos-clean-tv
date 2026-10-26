#!/bin/sh
# common.sh - shared helpers for lg-webos-clean-tv (sourced by the other scripts)
CT=/var/lib/webosbrew/cleantv
APP=$CT/launcher                       # master copy of the launcher (edit here, then run activate.sh)
CFG=$CT/config
HOME_T=/usr/palm/applications/com.webos.app.home                      # LG Home on the read-only rootfs
UPD=/media/system/apps/usr/palm/applications/com.webos.app.home       # "system_updatable" path: writable, scanned by SAM at boot
L=luna://com.webos.applicationManager
LP=luna://com.webos.service.homelaunchpoints
LSM=luna://com.webos.surfacemanager
ls2() { timeout 8 luna-send -n 1 -f "$@" 2>/dev/null; }
log() { echo "$(date '+%F %T') $*"; }
strip() { sed -e 's/#.*$//' -e 's/[[:space:]]*$//' -e '/^$/d' -e 's/\r$//' "$1" 2>/dev/null; }
sam_ok() { ls2 $L/getForegroundAppInfo '{}' | grep -q returnValue; }
home_type()   { ls2 $L/getAppInfo '{"id":"com.webos.app.home"}' | sed -n 's/.*"type": *"\([^"]*\)".*/\1/p' | head -1; }
home_folder() { ls2 $L/getAppInfo '{"id":"com.webos.app.home"}' | sed -n 's/.*"folderPath": *"\([^"]*\)".*/\1/p' | head -1; }
home_mounted() { grep -q " $HOME_T " /proc/mounts; }
home_running() { ls2 $L/running '{}' | grep -q '"id": *"com.webos.app.home"'; }
fg_app() { ls2 $LSM/getForegroundAppInfo '{}' | sed -n 's/.*"appId": *"\([^"]*\)".*/\1/p' | head -1; }
home_webproc() { ls2 luna://com.webos.service.webappmanager/listRunningApps '{"includeSysApps":true}' | tr -d ' \n' | sed -n 's/.*"webprocessid":"\([0-9]*\)","id":"com.webos.app.home".*/\1/p'; }
lg_home_pids() { for p in /proc/[0-9]*; do c=$( { tr '\0' ' ' < $p/cmdline; } 2>/dev/null); case "$c" in /usr/bin/flutter-client*com.webos.app.home*|/usr/bin/com.webos.app.home*) echo ${p#/proc/};; esac; done; }
# Launch point ids: apps use "<id>_default", HDMI inputs and other bookmarks use a NUMERIC id -> always resolve via listLaunchPoints.
lpid() { ls2 $LP/listLaunchPoints '{}' > /tmp/cleantv_lp.json; /usr/bin/node -e 'var j=JSON.parse(require("fs").readFileSync("/tmp/cleantv_lp.json","utf8"));var l=(j.launchPoints||[]).filter(function(l){return l.id===process.argv[1]})[0];console.log(l?l.launchPointId:process.argv[1]+"_default")' "$1" 2>/dev/null; }
# SAM re-reads one app's appinfo.json after block + release (no SAM restart). webOS 11 needs forceBlockSystemApp.
reread_app() {
  force=; grep -q '"forceBlockSystemApp"' /etc/palm/schemas/sam/applicationManager.blockSystemApp.schema 2>/dev/null && force=',"forceBlockSystemApp":false'
  ls2 $L/blockSystemApp "{\"id\":\"$1\"$force}" | grep -q '"returnValue": *true'; b=$?
  for _ in 1 2 3; do ls2 $L/releaseBlockSystemApp "{\"id\":\"$1\"}" | grep -q '"returnValue": *true' && return $b; sleep 1; done
  return 1
}
# Close the LG (Flutter) Home through SAM and wait until SAM has dropped it. Never `kill` it right before launching the launcher:
# SAM may register the Flutter process' death AFTER the web launch and drop the new instance too -> orphan in WAM, no window, black screen.
close_lg_home() {
  [ -n "$(lg_home_pids)" ] || return 0
  ls2 $L/closeByAppId '{"id":"com.webos.app.home"}' >/dev/null
  w=0; while [ $w -lt 6 ] && [ -n "$(lg_home_pids)" ]; do sleep 1; w=$((w+1)); [ $w -eq 1 ] && for p in $(lg_home_pids); do kill $p 2>/dev/null; done; done
  w=0; while [ $w -lt 10 ] && home_running; do sleep 1; w=$((w+1)); done
}
# Launch the launcher and verify it reaches the surface manager's foreground; otherwise clean up (SAM close, stray WAM renderer) and retry.
launch_home_verified() {
  t=1; while [ $t -le 3 ]; do
    [ "$(fg_app)" = com.webos.app.home ] && return 0
    ls2 $L/launch '{"id":"com.webos.app.home"}' >/dev/null
    v=0; while [ $v -lt 15 ]; do [ "$(fg_app)" = com.webos.app.home ] && return 0; sleep 1; v=$((v+1)); done
    log "launcher not in foreground after 15s (fg='$(fg_app)'), attempt $t -> cleanup"
    ls2 $L/closeByAppId '{"id":"com.webos.app.home"}' >/dev/null
    wp=$(home_webproc); [ -n "$wp" ] && kill -9 $wp 2>/dev/null
    sleep 3; t=$((t+1))
  done
  return 1
}
# Reload the launcher page for real. closeByAppId + launch shows the OLD page (WAM keeps the instance) - kill its renderer first.
reload_home() { ls2 $L/closeByAppId '{"id":"com.webos.app.home"}' >/dev/null; wp=$(home_webproc); [ -n "$wp" ] && kill -9 $wp 2>/dev/null; sleep 4; launch_home_verified; }
