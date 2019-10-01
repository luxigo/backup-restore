#!/bin/bash
#   backup-restore.sh - disk backup and restoration from command line
#   (c) 2019 Luc Deschenaux <luc.deschenaux@freesurf.ch>
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU Affero General Public License as
#   published by the Free Software Foundation, either version 3 of the
#   License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU Affero General Public License for more details.
#
#   You should have received a copy of the GNU Affero General Public License
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.


# The file name (or symbolic link name) of this script is the entry point.
# eg if you can create links with:
#     ln -s backup-restore.sh backup_device
#     ln -s backup-restore.sh select_and_restore_image
# then you can run from the command line:
#     backup_device /dev/sda1 /dev/sdb1 
# or  backup_device /dev/sda1 //server/share
# or  select_and_restore_image /dev/sda1 /dev/nvme0n1
# or  select_and_restore_image //serve/share /dev/nvme0n1 

set -x
set -e

BACKUP_DIR=${BACKUP_DIR:-.backup/} # default location of backuped disk images
DEFAULT_MACADDR=$(cat /sys/class/net/$(ip route show default | awk '/default/ {print $5}')/address|sed -r -e s/://g)
MACADDR=${MACADDR:-$DEFAULT_MACADDR}
MACHINEID=-${MACHINEID:-$MACADDR} # added to file names (optional)
TMPFILE=$(mktemp)
DEFAULT_USERNAME=${SUDO_USER:-$USER}
USERNAME=${USERNAME:-$DEFAULT_USERNAME}

# check dependencies
for required in dialog sort mount dd ; do
  if [ -z "$(which $required)" ] ; then
    echo ERROR: command $required not found >&2
    exit 1
  fi
done

if [ -z "$MACHINEID" ] ; then
  echo "Please define MACADDR or MACHINEID and try again" >&2
  exit 1
fi

trap cleanup EXIT

cleanup() {
  while read l ; do
    umount ${l:33} || true
  done < $TMPFILE
  rm $TMPFILE
}

is_mounted() {
  grep -q '^'$1'\s\|\s'$1'\s' /proc/mounts || false
}

assert_unmounted() {
  MD5=($(md5sum <<< $1))
  if ! grep -q ${MD5[0]} $TMPFILE ; then
    if is_mounted $1 ; then
      echo "$1 must be unmounted before operation !" >&2
      false
    fi
  fi
}

mount_storage() {
  STORAGE=$1
  MD5=($(md5sum <<< $STORAGE))
  if ! grep -q ${MD5[0]} $TMPFILE ; then
    MOUNTPOINT=/mnt/$(basename $STORAGE)
    assert_unmounted /mnt
    assert_unmounted $STORAGE
    mkdir -p $MOUNTPOINT
    if [ "${STORAGE:0:2}" == '//' ] ; then
      OPTIONS="-o username=$USERNAME,uid=0,gid=0,rw,nounix,iocharset=utf8,file_mode=0777,dir_mode=0777"
    else
      OPTIONS=
    fi
    mount $STORAGE $MOUNTPOINT $OPTIONS
    echo "${MD5[0]} $STORAGE"  >> $TMPFILE
  fi
}

umount_storage() {
  STORAGE=$1
  umount $STORAGE
  MD5=($(md5sum <<< $STORAGE))
  sed -r -i -e /${MD5[0]}/d $TMPFILE
}

backup_device() {
  SOURCE_DEVICE=$1
  STORAGE=$2
  DISK_IMAGE=/mnt/$(basename $STORAGE)/$BACKUP_DIR$(date +%Y%m%d-%H%M%S)$MACHINEID-$(basename $SOURCE_DEVICE).img
  assert_unmounted $SOURCE_DEVICE
  mount_storage $STORAGE
  mkdir -p $(dirname $DISK_IMAGE)
  dd if=$SOURCE_DEVICE of=$DISK_IMAGE bs=4M status=progress
  umount_storage $STORAGE
}

restore_device() {
  STORAGE=$1
  SOURCE_IMAGE=$2
  TARGET_DEVICE=$3
  assert_unmounted $STORAGE
  mount_storage $STORAGE
  DISK_IMAGE=/mnt/$(basename $STORAGE)/$BACKUP_DIR$SOURCE_IMAGE
  test -f $DISK_IMAGE
  dd if=$DISK_IMAGE of=$TARGET_DEVICE bs=4M status=progress
  umount_storage $STORAGE
}

select_and_restore_image() {
  STORAGE=$1
  TARGET_DEVICE=$2
  select_image $STORAGE $TARGET_DEVICE
  if [ -z "$IMAGE" ] ; then
    echo "no image selected !" >&2
    umount_storage $STORAGE
    false
  else
    restore_device $STORAGE $IMAGE $TARGET_DEVICE
  fi
}

select_image() {
  STORAGE=$1
  TARGET_DEVICE=$2
  assert_unmounted $STORAGE
  mount_storage $STORAGE

  # build images list
  list=()
  while read l ; do
    [ -n "$l" ] && list+=($(basename $l))
  done <<< $(find /mnt/$(basename $STORAGE)/$BACKUP_DIR -name \*$MACHINEID-$(basename $TARGET_DEVICE).img | sort -r)

  if [ ${#list[*]} -eq 0 ] ; then
    echo no images found in $STORAGE  >&2
    umount_storage $STORAGE
    false

  else
    # select image to restore
    exec 3>&1
    IMAGE=$(dialog --backtitle "Restore $TARGET_DEVICE from $STORAGE" --no-items --title "Select image to restore" --menu "" 0 0 0 "${list[@]}" 2>&1 1>&3) || true
    exec 3>&-
  fi
}

# default entry point
backup-restore() {
  list=()
  list+=('Backup nvme0n1 to sda1')
  list+=('Restore nvme0n1 from sda1')
  list+=('Backup nvme0n1 to server')
  list+=('Restore nvme0n1 from server')

  # select action
  exec 3>&1
  ACTION=$(dialog --backtitle "Backup/Restore" --no-items --title "Select action" --menu "" 0 0 0 "${list[@]}" 2>&1 1>&3) || true
  exec 3>&-
  if [ -z "$ACTION" ] ; then
    echo "no action selected !" >&2
    false

  else
    COMMAND=$(echo $ACTION | tr 'A-Z ' 'a-z_')
    $COMMAND
  fi
}

backup_nvme0n1_to_sda1() {
  backup_device /dev/nvme0n1 /dev/sda1
}

restore_nvme0n1_from_sda1() {
  select_and_restore_image /dev/sda1 /dev/nvme0n1
}

backup_nvme0n1_to_server() {
  backup_device /dev/nvme0n1 //192.168.200.2/backup
}

restore_nvme0n1_from_server() {
  select_and_restore_image //192.168.200.2/backup /dev/nvme0n1
}

# the command name (or symbolic link name) is the entry point
COMMAND=$(basename $0 .sh)
$COMMAND "$@"
