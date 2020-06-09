#!/usr/bin/env bash

source /mnt/fpool/FAST/scripts/zfs-autobackup/backup_common.sh

echo "Starting zfs-autobackup to usb"
backup fpool tpool.backup.wd6tb.8r3f 0 0
#backup fpool tpool.backup.wd6tb.xxxx 0 0
