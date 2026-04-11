#!/usr/bin/env bash

# Shared code and variables for ts-tools

source /usr/local/lib/display.sh
source /usr/local/lib/device.sh

TS_SHARED_VERSION="20260411"

g_infofile=info.json
g_backuppath=/mnt/backup
g_backupdir="ts"
g_excludesfile="/etc/ts-excludes"
g_bootfile="grubx64.efi"  # Default for non-secure boot
g_snapshots=()            # Populated by collect_snapshots as needed

verify_sudo() {
  if [[ "$EUID" != 0 ]]; then
    showx "This must be run as sudo.\n"
    exit 1
  fi
}

get_device() {
  echo "/dev/$(lsblk -ln -o NAME,UUID,PARTUUID,LABEL | grep "${1#/dev/}" | tr -s ' ' | cut -d ' ' -f1)"
}

# Populate g_snapshots with all snapshots found under path, optionally filtered to target hostname.
# Each entry is "hostname/snapshotname|hostname  snapshotname: comment"
# Entries are sorted by hostname then snapshotname.
collect_snapshots() {
  local path=$1
  local target=$2

  local hostname
  local comment
  local snapshot
  local infopath
  local hostnamedir
  local raw=()
  local entry

  g_snapshots=()

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
      raw+=("$target/$snapshot|$hostname  $snapshot: $comment")
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
        raw+=("${hostnamedir##*/}/$snapshot|$hostname  $snapshot: $comment")
      done < <( find "$hostnamedir" -mindepth 1 -maxdepth 1 -type d | xargs -I{} basename {} | grep -E '^[0-9]{8}_[0-9]{6}$' | sort )
    done < <( find "$path" -mindepth 1 -maxdepth 1 -type d | sort )
  fi

  # Sort by the display portion (hostname first, then timestamp)
  while IFS= read -r entry; do
    g_snapshots+=("$entry")
  done < <( printf '%s\n' "${raw[@]}" | sort -t'|' -k2 )
}

select_snapshot() {
  local device=$1
  local path=$2
  local target=$3

  local count
  local entry
  local labels=()
  local selection
  local name
  local idx

  collect_snapshots "$path" "$target"

  if [ ${#g_snapshots[@]} -eq 0 ]; then
    if [ -n "$target" ]; then
      showx "There are no backups on $device for '$target'"
    else
      showx "There are no backups on $device"
    fi
    return
  fi

  # Build display-only labels for select
  for entry in "${g_snapshots[@]}"; do
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
        name="${g_snapshots[$idx]%%|*}"
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
