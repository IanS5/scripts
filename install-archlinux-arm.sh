#!/usr/bin/bash
set -e

CALL_NAME="$0"
WOKRDIR="/tmp/install-archlinux-arm.sh.$(date +s)"

_usage() {
    printf "USAGE: $CALL_NAME DEVICE\n"
    printf "ARGUMENTS:\n"
    printf "\tDEVICE: the device to install archlinux-arm onto\n"
}

partition() {
    sfdisk --delete "$1"
    sfdisk "$1" << EOF
    , 100M,c
    ,,
EOF
}

mount_dirs() {
   mkdir -p $WORKDIR/{root,boot}

    mkfs.vfat "$1"1
    mount "$1"1 "$WORKDIR/boot"
    mkfs.ext4 "$1"2 
    mount "$1"2 "$WORKDIR/root"
}

if [[ $# -lt 1 ]]; then
    _usage
    exit 1
fi

if [[ -f $1 ]]; then
    printf "could not find device \"%s\"" "$1"
    exit 1
fi

if [[ ! -w $1 ]]; then
    echo "root required to access disk:"
    export -f partition
    export -f mount_dirs
    su -c "partition $1; mount_dirs $1"
else
    partition
    mount_dirs
fi
exit 0
pushd $WORKDIR

wget 'http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-2-latest.tar.gz'
bsdtar -xpf ArchLinuxARM-rpi-2-latest.tar.gz -C root
sync

popd

mv $WORKDIR/root/boot/* $WORKDIR/boot

umount $WORKDIR/{root,boot}
