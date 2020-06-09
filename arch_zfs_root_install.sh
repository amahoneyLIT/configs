exit 0 # don't run this as a script

# Starting from booted live USB at 12:40PM
# Boot to ubuntu 20.04 LTS image (zfs-0.8.3-1)

sudo su
mkdir /tmpfs
mount -t tmpfs none /tmpfs
# download and extract the bootstrap image into the tmpfs
tar xzf archlinux-bootstrap-2020.05.01-x86_64.tar.gz

mount --bind /tmpfs/root.x86_64 /tmpfs/root.x86_64
/tmpfs/root.x86_64/bin/arch-chroot /tmpfs/root.x86_64/
cat /proc/sys/kernel/random/entropy_avail
pacman-key --init
pacman-key -r F75D9D76
# Works!
exit


# Enable ssh
apt update
apt install --yes openssh-server
systemctl restart ssh
exit
passwd

# find and replace YOUR-DISK-ID
DISK=/dev/disk/by-id/YOUR-DISK-ID
sgdisk --zap-all $DISK

# UEFI
sgdisk     -n2:1M:+512M   -t2:EF00 $DISK
# boot pool (grub doesn't support all ZFS features, so create limited pool)
sgdisk     -n3:0:+1G      -t3:BF01 $DISK
# root partition
sgdisk     -n4:0:0        -t4:BF01 $DISK


mkdosfs -F 32 -s 1 -n EFI ${DISK}-part2

# man zpool-features shows what grub can't handle... seems like only 2. Whatever
zpool create -f -o ashift=12 -d \
    -o feature@async_destroy=enabled \
    -o feature@bookmarks=enabled \
    -o feature@embedded_data=enabled \
    -o feature@empty_bpobj=enabled \
    -o feature@enabled_txg=enabled \
    -o feature@extensible_dataset=enabled \
    -o feature@filesystem_limits=enabled \
    -o feature@hole_birth=enabled \
    -o feature@large_blocks=enabled \
    -o feature@lz4_compress=enabled \
    -o feature@spacemap_histogram=enabled \
    -o feature@userobj_accounting=enabled \
    -o feature@zpool_checkpoint=enabled \
    -o feature@spacemap_v2=enabled \
    -o feature@project_quota=enabled \
    -o feature@resilver_defer=enabled \
    -o feature@allocation_classes=enabled \
    -O acltype=posixacl -O canmount=off -O compression=lz4 -O devices=off \
    -O normalization=formD -O relatime=on -O xattr=sa \
    -o cachefile=none -o autotrim=on \
    -O mountpoint=none -R /tmpfs/root.x86_64/mnt bpool ${DISK}-part3

zfs create -o canmount=off -o mountpoint=none bpool/BOOT
zfs create -o canmount=noauto -o mountpoint=/boot bpool/BOOT/default

cryptsetup luksFormat -c aes-xts-plain64 -s 512 -h sha512 --type luks1 ${DISK}-part4
cryptsetup luksOpen --allow-discards ${DISK}-part4 cryptroot

zpool create -f -o ashift=12 \
    -O acltype=posixacl -O canmount=off -O compression=lz4 \
    -O normalization=formD -O relatime=on -O xattr=sa \
    -o autotrim=on \
    -O mountpoint=/mnt -R /tmpfs/root.x86_64/mnt \
    rpool /dev/mapper/cryptroot

zfs create -o canmount=off -o mountpoint=none rpool/sys
zfs create -o canmount=off -o mountpoint=none rpool/sys/ROOT
zfs create -o canmount=noauto -o mountpoint=/ rpool/sys/ROOT/default
zfs mount rpool/sys/ROOT/default
zfs mount bpool/BOOT/default

zfs create -o mountpoint=/home rpool/sys/home
# **** LATER set relevant mountpoint to legacy

mkdir -p /tmpfs/root.x86_64/mnt/boot/efi
mount ${DISK}-part2 /tmpfs/root.x86_64/mnt/boot/efi
# Check later that we get the right fstab options


#===================================
# Install arch

nano /tmpfs/root.x86_64/etc/pacman.d/mirrorlist
/tmpfs/root.x86_64/bin/arch-chroot /tmpfs/root.x86_64/

# check mount

# The entropy pool size in Linux is viewable through the file /proc/sys/kernel/random/entropy_avail and should generally be at least 2000 bits (out of a maximum of 4096). 
# check entropy before running the next 2 commands
cat /proc/sys/kernel/random/entropy_avail
pacman-key --init
pacman-key --populate archlinux
pacman-key -r F75D9D76
pacman-key --lsign-key F75D9D76

pacman -Syu

pacman -S nano base-devel
# 12:47
pacstrap -i /mnt base base-devel mkinitcpio nano linux-lts linux-firmware
# 12:50

genfstab -U -p /mnt >> /mnt/etc/fstab
echo "tmpfs   /tmp         tmpfs   nodev,nosuid                  0  0" >> /mnt/etc/fstab


DISK=/dev/disk/by-id/YOUR-DISK-ID
echo PARTUUID=$(blkid -s PARTUUID -o value ${DISK}-part2) \
    /boot/efi vfat nofail,x-systemd.device-timeout=1 0 1 >> /mnt/etc/fstab

nano /mnt/etc/fstab
# comment out root
# let bpool be legacy
# let home be legacy
# comment out extra efi entry. Keep /boot/efi last


umount /mnt/boot/efi
umount /mnt/home
umount /mnt/boot

exit

zfs set mountpoint=legacy rpool/sys/home
zfs set mountpoint=legacy bpool/BOOT/default

/tmpfs/root.x86_64/bin/arch-chroot /tmpfs/root.x86_64/

# enter chroot
arch-chroot /mnt /bin/bash
mount /boot
mount /boot/efi
mount /home

ln -sf /usr/share/zoneinfo/Canada/Pacific /etc/localtime 

nano /etc/locale.gen
# keep en_CA and en_US
locale-gen
echo LANG=en_US.UTF-8 > /etc/locale.conf
unset LANG
source /etc/profile.d/locale.sh

# Change arch-tower to your desired computer name
echo arch-tower > /etc/hostname

cat > /etc/hosts << EOF
127.0.0.1    localhost
::1	         localhost
127.0.1.1    arch-tower.localdomain    arch-tower
EOF

nano /etc/mkinitcpio.conf
# add keyboard before zfs, zfs before filesystems, add shutdown at the end
# delete fsck
# add encrypt before zfs
HOOKS=(base udev autodetect modconf block keyboard encrypt zfs filesystems)

pacman -S intel-ucode man pv cifs-utils

# if you do custom grub config, config microcode per https://wiki.archlinux.org/index.php/Microcode


nano /etc/pacman.conf
# add to end
[archzfs]
Server = http://archzfs.com/$repo/x86_64
Server = http://mirror.sum7.eu/archlinux/archzfs/$repo/x86_64
Server = https://mirror.biocrafting.net/archlinux/archzfs/$repo/x86_64

pacman-key -r F75D9D76
pacman-key --lsign-key F75D9D76
pacman -Syyu

# 12:56
pacman -S zfs-dkms zfs-utils linux-lts-headers
# Nice! CPU went to 100% on 8 cores and only 1 minute to build!!

# substitue andy with your user name
passwd
useradd -m andy -G uucp,lp,audio,wheel
passwd andy
echo 'andy ALL=(ALL) ALL' > /etc/sudoers.d/10-andy

pacman -S realtime-privileges
usermod -a -G realtime andy

pacman -S networkmanager
systemctl enable NetworkManager.service

## DO NOT EXECUTE THESE TWO LINES - unbootable system, don't know how to fix. Fixup after first boot.
#zpool set cachefile=/etc/zfs/zpool.cache bpool
#zgenhostid $(hostid)

mkinitcpio -p linux-lts

pacman -S efibootmgr grub os-prober

nano /etc/default/grub
GRUB_CMDLINE_LINUX="zfs=rpool/sys/ROOT/default cryptdevice=/dev/disk/by-id/YOUR-DISK-ID-part4:cryptroot"
# remove quiet

ZPOOL_VDEV_NAME_PATH=1 grub-install --target=x86_64-efi --efi-directory /boot/efi --bootloader-id=GRUB
ZPOOL_VDEV_NAME_PATH=1 grub-mkconfig -o /boot/grub/grub.cfg
# 1:00 PM

exit
exit

umount /tmpfs/root.x86_64/mnt/boot/efi
umount /tmpfs/root.x86_64/mnt/home
umount /tmpfs/root.x86_64/mnt/boot
umount /tmpfs/root.x86_64/mnt

zpool export rpool
zpool export bpool
cryptsetup luksClose cryptroot


# reboot
# you should see fail to mount /boot

zpool import bpool
mount /boot
mount /boot/efi
zpool set cachefile=/etc/zfs/zpool.cache bpool
zgenhostid $(hostid)
mkinitcpio -p linux-lts

# 1:03 PM (23 minutes)

# reboot. should see /boot mount properly

zfs snapshot bpool/BOOT/default@fresh-install
zfs snapshot rpool/sys/ROOT/default@fresh-install
zfs snapshot rpool/sys/home@fresh-install

#==============================================================
# System setup

sudo pacman -S openssh
sudo systemctl start sshd
exit

sudo timedatectl set-ntp true

# only if using systemd-resolvd
# sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

sudo pacman -Syu
sudo pacman -S xorg plasma-meta ttf-anonymous-pro ttf-dejavu ttf-freefont ttf-liberation adobe-source-code-pro-fonts kdialog kfind dolphin dolphin-plugins spectacle kio-extras ark kompare gwenview okular kate kwrite konsole kolourpaint imagemagick inkscape gimp keepass vlc phonon-qt5-vlc mediainfo mpv ffmpegthumbs ffmpegthumbnailer obs-studio openssh chromium firefox youtube-dl firejail code meld git pycharm-community-edition python-qtconsole python-numpy python-matplotlib python-pandas python-scipy nvidia-lts nvidia-utils nvidia-settings tree firefox-ublock-origin firefox-tree-style-tab firefox-noscript firefox-extension-https-everywhere qt5-doc qt5-examples qtcreator cloc cuda cmake valgrind gl2ps glm go cython pyside2 shiboken2 python-pillow python-pyaudio python-pyqt5 lxd cdrtools qemu ovmf jack2 pulseaudio-alsa qjackctl rtaudio patchage pciutils alsa-utils audacity libsamplerate libreoffice-fresh emacs

# Remove nvidia/cuda if non-nvidia system and add mesa, vulkan-intel

sudo usermod -a -G lxd andy

# nvidia system only
sudo nvidia-xconfig
sudo nano /etc/modprobe.d/blacklist.conf
install i915 /usr/bin/false
install intel_agp /usr/bin/false

# sudo mkinitcpio -P
sudo systemctl enable sddm.service
sudo reboot

#=======================
# First KDE login.

- move panel location [plasmashellrc]
- change clock settings; B&H Lucida [.config/plasma-org.kde.plasma.desktop-appletsrc]
- change launcher to Kicker
- system tray -> disable clipboard. Always show night color.

Task Manager settings
- Icon Size small
- middle click close window
- Don't show applications that use audio
- Disable cycle with mousewheel (90% of the time it's an accident and confuse last window used ordering)

System settings
- Workspace behavior
    - General Behavior
        - double click to open files and folder

    - screen locking
        - adjust timeout
        - diable media controls

    - Desktop effects
        - Wobbly windows
        - Magic Lamp
        - eye On Screen

- Window Management
    - Task Switcher
        - set to flipswitch

- Applications
    - Chromium default

- Application Style
    - Window Decorations
        - Titlebar Buttons
            - add Keep above

- Power Management
    - Turn off screen after X minutes

- Input Devices / Keyboard
    - NumLock on
    - CapsLock / Ctrl

------------

pacman -S ripgrep python-opengl

# install yay from github

yay -S nomachine

pacman -S zip pandoc

pacman -S python-pip fish
chsh -s /bin/fish
sudo pip install pypyp


#=============
# in fish shell

function hist; history -t -R | pyp '["\t".join(pair) for pair in zip(lines[::2],lines[1::2])]' | less +G; end; funcsave hist
set -U fish_prompt_pwd_dir_length 0

#==============
# add non-lts kernel

pacman -S linux linux-headers nvidia
mkinitcpio -P
