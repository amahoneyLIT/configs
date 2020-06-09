#!/usr/bin/env bash

source /mnt/fpool/FAST/scripts/zfs-autobackup/backup_common.sh

echo "Starting zfs-autobackup to tpool"
backup fpool tpool 0 0
