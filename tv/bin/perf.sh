#!/bin/sh
# perf.sh - performance levers (called by the boot hook). Config: config/perf.conf. Reversible: reboot without the hook.
# 1) zram: compressed swap in RAM ahead of the slow eMMC swap partition. 2 GB RAM plus resident apps (Netflix/YouTube/...) otherwise
#    swap to flash and app switching stutters. The zram device exists in LG's kernel but is unused.
# 2) GPU (Mali) power policy always_on: no wake-up latency at the start of UI animations (costs a little power).
. /var/lib/webosbrew/cleantv/bin/common.sh
ZRAM_MB=512; GPU_ALWAYS_ON=1
[ -f $CFG/perf.conf ] && . $CFG/perf.conf
if [ "$ZRAM_MB" -gt 0 ] 2>/dev/null && [ -e /sys/block/zram0/disksize ] && ! grep -q zram0 /proc/swaps; then
  echo lz4 > /sys/block/zram0/comp_algorithm 2>/dev/null || echo lzo > /sys/block/zram0/comp_algorithm 2>/dev/null
  echo $((ZRAM_MB*1024*1024)) > /sys/block/zram0/disksize 2>/dev/null && mkswap /dev/zram0 >/dev/null 2>&1 && swapon -p 10 /dev/zram0 2>/dev/null && log "zram swap ${ZRAM_MB} MB active"
fi
[ "$GPU_ALWAYS_ON" = 1 ] && [ -w /sys/class/misc/mali0/device/power_policy ] && echo always_on > /sys/class/misc/mali0/device/power_policy 2>/dev/null
[ "$1" = "-v" ] && { grep zram /proc/swaps; cat /sys/class/misc/mali0/device/power_policy 2>/dev/null; }
exit 0
