#!/bin/bash

original="default"
backup="backup"

zfs destroy bpool/BOOT/${backup}
zfs destroy rpool/sys/ROOT/$backup
zfs destroy rpool/sys/home_${backup}

zfs destroy bpool/BOOT/${original}@${backup}
zfs destroy rpool/sys/ROOT/${original}@${backup}
zfs destroy rpool/sys/home@${backup}
