#!/usr/bin/env python3

import os

path = '/boot/grub/grub.cfg'
# path = 'grub.cfg'
cfg = open(path).read()

a, b, c = cfg.partition('\nmenuentry')
d, e, f = c.partition('\n}')

assert a + b + d + e + f == cfg

header = a
first_entry = b + d + e
footer = f

new_entry = first_entry.replace('OOT/default', 'OOT/backup').replace("Arch Linux", "Arch Linux Backup")
new_cfg = header + first_entry + new_entry + footer

os.rename(path, path + '.old')
with open(path, 'w') as f:
    f.write(new_cfg)
