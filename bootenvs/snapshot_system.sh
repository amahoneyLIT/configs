#!/bin/bash

timestamp="$(date --iso-8601=minutes)"

original="default"
backup=$timestamp

zfs snapshot bpool/BOOT/${original}@${backup}
zfs snapshot rpool/sys/ROOT/${original}@${backup}
zfs snapshot rpool/sys/home@${backup}
