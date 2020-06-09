#!/bin/bash

#timestamp="$(date --iso-8601=minutes)"

original="default"
backup="backup"

zfs snapshot bpool/BOOT/${original}@${backup}
zfs snapshot rpool/sys/ROOT/${original}@${backup}
zfs snapshot rpool/sys/home@${backup}

zfs clone bpool/BOOT/${original}@${backup} bpool/BOOT/${backup}
zfs clone rpool/sys/ROOT/${original}@${backup} rpool/sys/ROOT/$backup
zfs clone rpool/sys/home@${backup} rpool/sys/home_${backup}

## -o property=value

zfs set mountpoint=legacy bpool/BOOT/${backup}
zfs set mountpoint=legacy rpool/sys/ROOT/${backup}
zfs set mountpoint=legacy rpool/sys/home_${backup}

mntroot=/mnt/clone_${backup}
mkdir ${mntroot}

mount -t zfs rpool/sys/ROOT/${backup} ${mntroot}
mount -t zfs bpool/BOOT/${backup} ${mntroot}/boot

sed -i "s|OOT/${original}|OOT/${backup}|g" ${mntroot}/etc/fstab
sed -i "s|rpool/sys/home|rpool/sys/home_${backup}|g" ${mntroot}/etc/fstab

sed -i "s|OOT/${original}|OOT/${backup}|g" ${mntroot}/boot/grub/grub.cfg

umount ${mntroot}/boot
umount ${mntroot}
rm -r ${mntroot}
zfs set mountpoint=/ canmount=noauto rpool/sys/ROOT/${backup}
