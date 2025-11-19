#!/usr/bin/env bash

# List the ts_backups

source /usr/local/lib/ts_shared.sh

show_syntax() {
  echo "List all snapshots created by ts_backup."
  echo "Syntax: $(basename $0) <backup_device>"
  echo "Where:  <backup_device> can be a device designator (e.g., /dev/sdb6), a UUID, filesystem LABEL, or partition UUID"
  echo "NOTE:   Must be run as sudo."
  exit  
}

list_snapshots() {
  local device=$1 path=$2

  # Get the snapshots
  local snapshots=() note name
  local i=0
  while IFS= read -r name; do
    if [ $i -eq 0 ]; then
      show "Snapshot files on $device"
    fi
    if [ -f "$path/$name/$g_descfile" ]; then
      note="$(cat $path/$name/$g_descfile)"
    else
      note="<no desc>"
    fi
    show "$name: $note"
    ((i++))
  done < <( ls -1 "$path" | sort )

  if [ $i -eq 0 ]; then
    showx "There are no backups on $device"
  fi
}

# --------------------
# ------- MAIN -------
# --------------------

trap 'unmount_device_at_path "$g_backuppath"' EXIT

# Get the arguments
if [ $# -ge 1 ]; then
  backupdevice="/dev/$(lsblk -ln -o NAME,UUID,PARTUUID,LABEL | grep "${1#/dev/}" | tr -s ' ' | cut -d ' ' -f1)"
else
  show_syntax
fi

verify_sudo

if [ ! -b $backupdevice ]; then
  printx "No valid backup device was found for '$device'."
  exit
fi

mount_device_at_path "$backupdevice" "$g_backuppath" "$g_backupdir"
list_snapshots "$backupdevice" "$g_backuppath/$g_backupdir"

