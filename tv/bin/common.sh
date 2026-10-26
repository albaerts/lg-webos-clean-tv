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
lg_home_pids() { for p in /proc/[0-9]*; do c=$( { tr '\0' ' ' < $p/cmdline; } 2>/dev/null); case "$c" in /usr/bin/flutter-client*com.webos.app.home*|/usr/bin/com.webos.app.home*) echo ${p#/proc/};; esac; done; }
home_running() { ls2 $L/running '{}' | grep -q '"id": *"com.webos.app.home"'; }
fg_app() { ls2 luna://com.webos.surfacemanager/getForegroundAppInfo '{}' | sed -n 's/.*"appId": *"\([^"]*\)".*/\1/p' | head -1; }
home_webproc() { ls2 luna://com.webos.service.webappmanager/listRunningApps '{"includeSysApps":true}' | tr -d ' \n' | sed -n 's/.*"webprocessid":"\([0-9]*\)","id":"com.webos.app.home".*/\1/p'; }
# Close the LG (Flutter) Home through SAM and wait until SAM has dropped it. Never `kill` it right before launching the
# launcher: SAM may register the Flutter process' death AFTER the web launch and drop the new instance too -> orphan in WAM,
# no window, black screen (seen 2026-10-26 on a boot where bootd had opened LG Home first).
close_lg_home() {
  [ -n "$(lg_home_pids)" ] || return 0
  ls2 $L/closeByAppId '{"id":"com.webos.app.home"}' >/dev/null
  w=0; while [ $w -lt 6 ] && [ -n "$(lg_home_pids)" ]; do sleep 1; w=$((w+1)); [ $w -eq 1 ] && for p in $(lg_home_pids); do kill $p 2>/dev/null; done; done   # SAM's close returns true but does not end LG Home; the kill is fine once we wait for SAM below
  w=0; while [ $w -lt 10 ] && home_running; do sleep 1; w=$((w+1)); done
}
# Launch the launcher and verify it reaches the LSM foreground; otherwise clean up (SAM close, stray WAM renderer) and retry.
launch_home_verified() {
  t=1; while [ $t -le 3 ]; do
    ls2 $L/launch '{"id":"com.webos.app.home"}' >/dev/null
    v=0; while [ $v -lt 15 ]; do [ "$(fg_app)" = com.webos.app.home ] && return 0; sleep 1; v=$((v+1)); done
    log "launcher not in foreground after 15s (fg='$(fg_app)'), attempt $t -> cleanup"
    ls2 $L/closeByAppId '{"id":"com.webos.app.home"}' >/dev/null
    wp=$(home_webproc); [ -n "$wp" ] && kill -9 $wp 2>/dev/null
    sleep 3; t=$((t+1))
  done
  return 1
}
# SAM re-reads one app's appinfo.json after block + release (no SAM restart). webOS 11 needs forceBlockSystemApp.
reread_app() {
  force=; grep -q '"forceBlockSystemApp"' /etc/palm/schemas/sam/applicationManager.blockSystemApp.schema 2>/dev/null && force=',"forceBlockSystemApp":false'
  ls2 $L/blockSystemApp "{\"id\":\"$1\"$force}" | grep -q '"returnValue": *true'; b=$?
  for _ in 1 2 3; do ls2 $L/releaseBlockSystemApp "{\"id\":\"$1\"}" | grep -q '"returnValue": *true' && return $b; sleep 1; done
  return 1
}
