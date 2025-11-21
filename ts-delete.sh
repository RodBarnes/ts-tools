#!/usr/bin/env bash

# Delete ts-backups

source /usr/local/lib/ts-shared.sh

show_syntax() {
  echo "Delete a snapshot created with ts-backup."
  echo "Syntax: $(basename $0) <backup_device>"
  echo "Where:  <backup_device> can be a device designator (e.g., /dev/sdb6), a UUID, filesystem LABEL, or partition UUID"
  echo "NOTE:   Must be run as sudo."
  exit  
}

delete_snapshot() {
  local path=$1 name=$2
  local snapshot_dir="$path/$name"
  local guid=$(cat /proc/sys/kernel/random/uuid)
  local empty_dir=$(mktemp -d /tmp/empty.$guid)

  showx "This will completely and IRREVERSIBLY DELETE the snapshot '$name'."
  showx "All other remaining snapshots will stay fully intact and restorable."
  readx "Are you sure you want to proceed? (y/N)" yn
  if [[ $yn != "y" && $yn != "Y" ]]; then
    showx "Operation cancelled."
  else
    show "Safely deleting snapshot '$name' (this may take a while)..."

    # Use rsync to delete the snapshot and preserve remaining hard links
    # rsync -a --delete --quiet "$empty_dir/" "$snapshot_dir/"

    rsync -a --delete --quiet \
          --filter="protect /dev/" \
          --filter="protect /proc/" \
          --filter="protect /sys/" \
          --filter="protect /run/" \
          --filter="protect /tmp/" \
          --filter="protect /mnt/" \
          --filter="protect /media/" \
          --filter="exclude *" \
          "$empty_dir/" "$snapshot_dir/"

    # Now remove the now-empty directory itself
    rmdir "$snapshot_dir" 2>/dev/null || rm -rf "$snapshot_dir"

    show "Snapshot '$name' deleted safely."
  fi

  rm -rf "$empty_dir"
}

# --------------------
# ------- MAIN -------
# --------------------

trap 'unmount_device_at_path "$g_backuppath"' EXIT

# Get the arguments
if [ $# -ge 1 ]; then
  backupdevice=$(get_device "$1")
else
  show_syntax
fi

verify_sudo

if [[ ! -b $backupdevice ]]; then
  printx "No valid backup device was found for '$device'."
  exit
fi

mount_device_at_path "$backupdevice" "$g_backuppath" "$g_backupdir"
while true; do
  snapshotname=$(select_snapshot "$backupdevice" "$g_backuppath/$g_backupdir")
  if [ ! -z $snapshotname ]; then
    delete_snapshot "$g_backuppath/$g_backupdir" "$snapshotname"
  else
    exit
  fi
done
