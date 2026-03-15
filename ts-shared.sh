#!/usr/bin/env bash

# Shared code and variables for ts-tools

source /usr/local/lib/display.sh
source /usr/local/lib/device.sh

g_infofile=info.json
g_backuppath=/mnt/backup
g_backupdir="ts"
g_excludesfile="/etc/ts-excludes"
g_bootfile="grubx64.efi"  # Default for non-secure boot

verify_sudo() {
  if [[ "$EUID" != 0 ]]; then
    showx "This must be run as sudo.\n"
    exit 1
  fi
}

get_device() {
  echo "/dev/$(lsblk -ln -o NAME,UUID,PARTUUID,LABEL | grep "${1#/dev/}" | tr -s ' ' | cut -d ' ' -f1)"
}

select_snapshot() {
  local device=$1 path=$2

  local snapshots=() comment hostname name count

  # Enumerate all UUID subdirectories, then snapshots within each, sorted by hostname then timestamp
  while IFS= read -r uuiddir; do
    while IFS= read -r backup; do
      local infopath="$uuiddir/$backup/$g_infofile"
      if [ -f "$infopath" ]; then
        hostname=$(jq -r '.hostname' "$infopath")
        comment=$(jq -r '.comment' "$infopath")
      else
        hostname="unknown"
        comment="<no desc>"
      fi
      snapshots+=("${uuiddir##*/}/$backup|$hostname  $backup: $comment")
    done < <( find "$uuiddir" -mindepth 1 -maxdepth 1 -type d | xargs -I{} basename {} | grep -E '^[0-9]{8}_[0-9]{6}$' | sort )
  done < <( find "$path" -mindepth 1 -maxdepth 1 -type d | sort )

  if [ ${#snapshots[@]} -eq 0 ]; then
    showx "There are no backups on $device"
    return
  fi

  # Sort entries by the display portion (hostname first, then timestamp) and rebuild array
  local sorted_snapshots=()
  while IFS= read -r entry; do
    sorted_snapshots+=("$entry")
  done < <( printf '%s\n' "${snapshots[@]}" | sort -t'|' -k2 )

  # Build display-only labels for select
  local labels=()
  for entry in "${sorted_snapshots[@]}"; do
    labels+=("${entry##*|}")
  done

  show "Listing backup files..."

  count="${#labels[@]}"
  ((count++))

  COLUMNS=1
  select selection in "${labels[@]}" "Cancel"; do
    if [[ "$REPLY" =~ ^[0-9]+$ && "$REPLY" -ge 1 && "$REPLY" -le $count ]]; then
      if [[ "$selection" == "Cancel" ]]; then
        echo "Operation cancelled." >&2
        break
      else
        # Map selected label back to its uuid/snapshot path token
        local idx=$(( REPLY - 1 ))
        name="${sorted_snapshots[$idx]%%|*}"
        break
      fi
    else
      showx "Invalid selection. Please enter a number between 1 and $count."
    fi
  done

  echo "$name"
}
