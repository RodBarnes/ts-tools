#!/usr/bin/env bash

# List the ts-backups

source /usr/local/lib/ts-shared.sh

show_syntax() {
  echo "List all snapshots created by ts-backup."
  echo "Syntax: $(basename $0) <backup_device>"
  echo "Where:  <backup_device> can be a device designator (e.g., /dev/sdb6), a UUID, filesystem LABEL, or partition UUID"
  echo "NOTE:   Must be run as sudo."
  exit
}

list_snapshots() {
  local device=$1 path=$2

  local comment hostname name
  local i=0

  # Collect all entries as "hostname|timestamp|comment" for sorting by hostname then timestamp
  local entries=()
  while IFS= read -r uuiddir; do
    while IFS= read -r name; do
      local infopath="$uuiddir/$name/$g_infofile"
      if [ -f "$infopath" ]; then
        hostname=$(jq -r '.hostname' "$infopath")
        comment=$(jq -r '.comment' "$infopath")
      else
        hostname="unknown"
        comment="<no desc>"
      fi
      entries+=("$hostname|$name|$comment")
    done < <( find "$uuiddir" -mindepth 1 -maxdepth 1 -type d | xargs -I{} basename {} | grep -E '^[0-9]{8}_[0-9]{6}$' | sort )
  done < <( find "$path" -mindepth 1 -maxdepth 1 -type d | sort )

  if [ ${#entries[@]} -eq 0 ]; then
    showx "There are no backups on $device"
    return
  fi

  show "Snapshot files on $device"

  # Sort by hostname then timestamp and display
  while IFS='|' read -r hostname name comment; do
    show "$hostname  $name: $comment"
    ((i++))
  done < <( printf '%s\n' "${entries[@]}" | sort )
}

cleanup() {
  unmount_device_at_path "$g_backuppath"
}

# --------------------
# ------- MAIN -------
# --------------------

trap 'cleanup' EXIT

# Get the arguments
if [ $# -ge 1 ]; then
  backupdevice=$(get_device "$1")
else
  show_syntax
fi

verify_sudo

if [[ ! -b $backupdevice ]]; then
  printx "No valid backup device was found for '$backupdevice'."
  exit
fi

mount_device_at_path "$backupdevice" "$g_backuppath" "$g_backupdir"
list_snapshots "$backupdevice" "$g_backuppath/$g_backupdir"
