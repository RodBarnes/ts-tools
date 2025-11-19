#!/usr/bin/env bash

# Shared code and variables for ts_tools

source /usr/local/lib/display.sh
source /usr/local/lib/device.sh

g_descfile=comment.txt
g_backuppath=/mnt/backup
g_backupdir="ts"
g_excludesfile="/etc/ts_excludes"
g_bootfile="grubx64.efi"  # Default for non-secure boot

verify_sudo() {
  if [[ "$EUID" != 0 ]]; then
    showx "This must be run as sudo.\n"
    exit 1
  fi
}

select_snapshot() {
  local device=$1 path=$2

  local snapshots=() comment count name

  # Get the snapshots and allow selecting
  while IFS= read -r backup; do
    if [ -f "$path/$backup/$g_descfile" ]; then
      comment=$(cat "$path/$backup/$g_descfile")
    else
      comment="<no desc>"
    fi
    snapshots+=("${backup}: $comment")
  done < <( find $path -mindepth 1 -maxdepth 1 -type d | cut -d '/' -f5 | sort )

  if [ ${#snapshots[@]} -eq 0 ]; then
    showx "There are no backups on $device"
  else
    show "Listing backup files..."

    # Get the count of options and increment to include the cancel
    count="${#snapshots[@]}"
    ((count++))

    COLUMNS=1
    select selection in "${snapshots[@]}" "Cancel"; do
      if [[ "$REPLY" =~ ^[0-9]+$ && "$REPLY" -ge 1 && "$REPLY" -le $count ]]; then
        case ${selection} in
          "Cancel")
            # If the user decides to cancel...
            echo "Operation cancelled." >&2
            break
            ;;
          *)
            name="${selection%%:*}"
            break
            ;;
        esac
      else
        showx "Invalid selection. Please enter a number between 1 and $count."
      fi
    done
  fi

  echo "$name"
}
