#!/bin/bash

original="default"
backup="backup"

zfs rollback bpool/BOOT/${original}@${backup}
zfs rollback rpool/sys/ROOT/${original}@${backup}
zfs rollback rpool/sys/home@${backup}
