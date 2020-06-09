#!/usr/bin/env bash

timestamp="$(date --iso-8601=minutes)"
logfolder="/mnt/fpool/FAST/logs/zfs-autobackup"
zfs_autobackup="/mnt/fpool/FAST/scripts/zfs-autobackup/.venv/bin/zfs-autobackup"
# Currently with 3.0rc9
pyp="/mnt/fpool/FAST/scripts/zfs-autobackup/.venv/bin/pyp"
# Currently 0.2.1

is_pool_imported() {
    zpool list -H -o name | grep -q "$1"
}

# # Stop autosnapshot timers to prevent conflicts - better solutions?
# systemctl stop zfs-snapshot-daily.timer
# systemctl stop zfs-snapshot-frequent.timer
# systemctl stop zfs-snapshot-hourly.timer
# systemctl stop zfs-snapshot-monthly.timer
# systemctl stop zfs-snapshot-weekly.timer

successes=0
failures=0
backup() {
    SRC="$1"
    TARGET="$2"
    lstrip="$3"
    raw="$4"

    args=(--progress --verbose --keep-source 2 --keep-target 2 \
	    --filter-properties com.sun:auto-snapshot \
	    --no-holds --strip-path $lstrip \
        --other-snapshots \
        --destroy-incompatible \
        --clear-mountpoint \
        --no-snapshot
    )
    if [ $raw -eq 1 ]; then
        args+=( "--raw" )
    fi
    # --rollback: Rollback changes on the target before starting a backup. (to last common snapshot)
    # --allow-empty
    # --other-snapshots Send over other snapshots as well, not just the ones created by this tool.

    # the exit code will indicate the number of failures
    $zfs_autobackup "${SRC}_to_${TARGET}" "${TARGET}/BACKUPS" \
	${args[@]} \
	2>&1 | tee -a "${logfolder}/${SRC}_to_${TARGET}_${timestamp}.log"

    result=$?
    if [ $result -eq 0 ]; then
        ((successes++))
    else
        ((failures++))
        echo result > "${logfolder}/${SRC}_to_${TARGET}_${timestamp}.err"
    fi

    # delete datasets on the backup which no longer exist on the host
    zfs list -t all -o name -H \
    | $pyp '[ z for z in lines if z.startswith("'${TARGET}'/BACKUPS/") and z[len("'${TARGET}'/BACKUPS/"):] not in lines]' \
    | $pyp 'print("zfs release zfs_autobackup:'"${SRC}_to_${TARGET}"' " + x); print("zfs destroy -Rr " + x)' \
    > "${logfolder}/destroy_dead_${SRC}_to_${TARGET}.sh"

    # Note: `zfs destroy -Rr` works for filesystems, volumes, snapshots; not bookmarks. TODO (if you ever use bookmarks)
    if [ -s "${logfolder}/destroy_dead_${SRC}_to_${TARGET}.sh" ]; then
        bash "${logfolder}/destroy_dead_${SRC}_to_${TARGET}.sh" | 2>&1 | tee -a "${logfolder}/${SRC}_to_${TARGET}_${timestamp}_destroyals.log"
    fi
}

# echo "Starting zfs-autobackup to: tpool"
# backup fpool tpool 0 0

# backup_attempts=0
# for TARGET in wd6tb_usb_0 wd6tb_usb_1
# do
#     if ! is_pool_imported $TARGET; then
#         zpool import $TARGET
#         if ! is_pool_imported $TARGET; then
#             echo "The following pool was not found: $TARGET"
#             continue
#         fi
#     fi
#     ((backup_attempts++))
#     echo "Starting zfs-autobackup to: $TARGET"

#     backup tpool $TARGET 0 1

#     zpool export $TARGET
# done

# if [ $backup_attempts -eq 0 ]; then
#     echo "No backup pools found!"
#     touch "${logfolder}/no-usb-pools_${timestamp}.err"
# fi

# # start timers back up
# systemctl start zfs-snapshot-daily.timer
# systemctl start zfs-snapshot-frequent.timer
# systemctl start zfs-snapshot-hourly.timer
# systemctl start zfs-snapshot-monthly.timer
# systemctl start zfs-snapshot-weekly.timer

