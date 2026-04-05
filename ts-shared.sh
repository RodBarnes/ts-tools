#!/usr/bin/env bash

# Shared code and variables for ts-tools

source /usr/local/lib/display.sh
source /usr/local/lib/device.sh

TS_SHARED_VERSION="20260404"

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
  local device=$1
  local path=$2
  local target=$3

  local snapshots=()
  local comment
  local hostname
  local name
  local count
  local hostnamedir
  local snapshot
  local infopath
  local sorted_snapshots=()
  local entry
  local labels=()
  local selection
  local idx

  if [ -n "$target" ]; then
    # Target specified -- iterate snapshots directly within the hostname directory
    while IFS= read -r snapshot; do
      infopath="$path/$target/$snapshot/$g_infofile"
      if [ -f "$infopath" ]; then
        hostname=$(jq -r '.hostname' "$infopath")
        comment=$(jq -r '.comment' "$infopath")
      else
        hostname="unknown"
        comment="<no desc>"
      fi
      snapshots+=("$target/$snapshot|$hostname  $snapshot: $comment")
    done < <( find "$path/$target" -mindepth 1 -maxdepth 1 -type d | xargs -I{} basename {} | grep -E '^[0-9]{8}_[0-9]{6}$' | sort )
  else
    # No target -- enumerate all hostname subdirectories
    while IFS= read -r hostnamedir; do
      while IFS= read -r snapshot; do
        infopath="$hostnamedir/$snapshot/$g_infofile"
        if [ -f "$infopath" ]; then
          hostname=$(jq -r '.hostname' "$infopath")
          comment=$(jq -r '.comment' "$infopath")
        else
          hostname="unknown"
          comment="<no desc>"
        fi
        snapshots+=("${hostnamedir##*/}/$snapshot|$hostname  $snapshot: $comment")
      done < <( find "$hostnamedir" -mindepth 1 -maxdepth 1 -type d | xargs -I{} basename {} | grep -E '^[0-9]{8}_[0-9]{6}$' | sort )
    done < <( find "$path" -mindepth 1 -maxdepth 1 -type d | sort )
  fi

  if [ ${#snapshots[@]} -eq 0 ]; then
    if [ -n "$target" ]; then
      showx "There are no backups on $device for '$target'"
    else
      showx "There are no backups on $device"
    fi
    return
  fi

  # Sort entries by the display portion (hostname first, then timestamp) and rebuild array
  while IFS= read -r entry; do
    sorted_snapshots+=("$entry")
  done < <( printf '%s\n' "${snapshots[@]}" | sort -t'|' -k2 )

  # Build display-only labels for select
  for entry in "${sorted_snapshots[@]}"; do
    labels+=("${entry##*|}")
  done

  show "Snapshot files..."

  count="${#labels[@]}"
  ((count++))

  COLUMNS=1
  select selection in "${labels[@]}" "Cancel"; do
    if [[ "$REPLY" =~ ^[0-9]+$ && "$REPLY" -ge 1 && "$REPLY" -le $count ]]; then
      if [[ "$selection" == "Cancel" ]]; then
        echo "Operation cancelled." >&2
        break
      else
        idx=$(( REPLY - 1 ))
        name="${sorted_snapshots[$idx]%%|*}"
        break
      fi
    else
      showx "Invalid selection. Please enter a number between 1 and $count."
    fi
  done

  echo "$name"
}

show_device_space() {
  local device=$1
  df -h --output=source,size,used,avail,pcent "$device" | tail -1 | \
    awk '{printf "Device %s: %s total, %s used, %s available (%s)\n", $1, $2, $3, $4, $5}'
}
