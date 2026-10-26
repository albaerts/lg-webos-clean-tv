#!/bin/sh
# delete-bloat.sh - OPTIONAL, destructive: delete LG payload on the WRITABLE app partition (/mnt/lg/appstore). Nothing on the read-only
# rootfs can be deleted (squashfs) - those parts are only hidden/stopped (lean.sh). Run: sh delete-bloat.sh --yes [--cast]
# Removes: LG store demo content (~1.2 GB), gallery/Always-Ready artwork (~0.5 GB), stale app copies superseded by newer built-ins.
# --cast additionally deletes Google Cast (apps + services under /media/system/apps); it only comes back with an LG firmware update.
. /var/lib/webosbrew/cleantv/bin/common.sh
[ "$1" = "--yes" ] || { echo "usage: sh delete-bloat.sh --yes [--cast]"; exit 1; }
P=/mnt/lg/appstore/preload
for d in $P/storedemo $P/igallery; do [ -d $d ] || continue; for m in $(grep " $d" /proc/mounts | awk '{print $2}'); do umount $m 2>/dev/null; done; rm -rf $d && log "deleted $d"; done
A=/media/system/apps/usr/palm/applications; S=/media/system/apps/usr/palm/services
# an updatable copy of an app that SAM does not use (a newer built-in exists) is dead weight
for d in $A/*; do id=$(basename $d); [ "$id" = com.webos.app.home ] && continue; f=$(ls2 $L/getAppInfo "{\"id\":\"$id\"}" | sed -n 's/.*"folderPath": *"\([^"]*\)".*/\1/p' | head -1); [ -n "$f" ] && [ "$f" != "$d" ] && ! grep -q " $d" /proc/mounts && rm -rf $d && log "deleted stale copy $d (SAM uses $f)"; done
if [ "$2" = "--cast" ]; then
  timeout 10 systemctl stop chromecast-provisioning.service 2>/dev/null; pkill -x com.webos.chrom; pkill -x chromecast-prov
  for d in $A/com.webos.chromecast $A/com.webos.chromecast-settings $S/com.webos.chromecast.core $S/com.webos.chromecast.cell $S/com.webos.chromecast.log $S/com.webos.ghp.runtime; do [ -e $d ] && { umount -l $d 2>/dev/null; rm -rf $d && log "deleted $d"; }; done
  grep -q CAST_OFF $CFG/lean.conf 2>/dev/null && sed -i 's/^CAST_OFF=.*/CAST_OFF=1/' $CFG/lean.conf || echo "CAST_OFF=1" >> $CFG/lean.conf
fi
df -h /mnt/lg/appstore | tail -1
