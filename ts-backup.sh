#!/usr/bin/env bash

# Create a snapshot using rsync command as done by TimeShift.

source /usr/local/lib/ts-shared.sh

show_syntax() {
  echo "Create a TimeShift-like snapshot of the system file excluding those identified in /etc/backup-excludes."
  echo "Syntax: $(basename $0) <backup_device> [-d|--dry-run] [-c|--comment comment]"
  echo "Where:  <backup_device> can be a device designator (e.g., /dev/sdb6), a UUID, filesystem LABEL, or partition UUID"
  echo "        [-d|--dry-run] means to do a 'dry-run' test without actually restoring the snapshot."
  echo "        [-c|--comment comment] is a quote-bounded comment for the snapshot"
  echo "        [-v|--verbose] will display the output log in process."
  echo "NOTE:   Must be run as sudo."
  exit
}

verify_available_space() {
  local device=$1
  local path=$2
  local minspace=$3

  local line
  local space
  local minspace
  local avail
  local yn
  local dev
  local size
  local used
  local avail
  local pcent
  local mount

  # Check how much space is left
  line=$(df "$path" -BG | sed -n '2p;')
  IFS=' ' read dev size used avail pcent mount <<< $line
  space=${avail%G}
  if [[ $space -lt $minspace ]]; then
    showx "The backupdevice '$device' has less only $avail space left of the total $size."
    read -p "Do you want to proceed? (y/N) " yn
    if [[ $yn != "y" && $yn != "Y" ]]; then
      show "Operation cancelled."
      exit
    else
      echo "User acknowledged that backup device has less than $avail space but proceeded." &>> "$g_logfile"
    fi
  else
    echo "Backup device has $avail or more space avaiable; proceeding with backup." &>> "$g_logfile"
  fi
}

create_snapshot() {
  local device=$1
  local path=$2
  local name=$3
  local comment=$4
  local dry=$5
  local perm=$6

  local latest
  local uuid
  local hostname
  local machine_id
  local json
  local used_before
  local excludearg
  local yn
  local dryrun_flag
  local sourcedevice

  if [[ -n "$perm" ]]; then
    show "The backup device does not support permmissions or ownership."
    show "The rsync will be performed without attempting to set these options."
  fi

  # Get the name of the most recent backup in this system's UUID subdirectory
  latest=$(ls -1 "$path" | grep -E '^[0-9]{8}_[0-9]{6}$' | sort -r | sed -n '1p;')

  if [ -f "$g_excludesfile" ]; then
    excludearg="--exclude-from=$g_excludesfile"
  else
    printx "No excludes file found at '$g_excludesfile'."
    readx "Proceed with a complete backup with no exclusions (y/N)" yn
    if [[ $yn != "y" && $yn != "Y" ]]; then
      show "Operation cancelled."
      exit
    fi
  fi

  # Create the snapshot
  [ -n "$dry" ] && dryrun_flag="--dry-run" || dryrun_flag=""

  # Capture device usage before rsync to calculate actual snapshot size
  used_before=$(df "$path" --output=used -BK | tail -1 | tr -d 'K')

  if [ -n "$latest" ]; then
    show "Creating incremental snapshot on '$device'..."
    # Snapshots exist so create incremental snapshot referencing the latest
    echo "rsync -aAX $dryrun_flag $perm --verbose --delete --link-dest=\"$path/$latest\" $excludearg / \"$path/$name/\"" &>> "$g_logfile"
    rsync -aAX $dryrun_flag $perm --verbose --delete --link-dest="$path/$latest" $excludearg / "$path/$name/" &>> "$g_logfile"
  else
    show "Creating full snapshot on '$device'..."
    # This is the first snapshot so create full snapshot
    echo "rsync -aAX $dryrun_flag $perm --verbose --delete $excludearg / \"$path/$name/\"" &>> "$g_logfile"
    rsync -aAX $dryrun_flag $perm --verbose --delete $excludearg / "$path/$name/" &>> "$g_logfile"
  fi

  if [ -z "$dry" ]; then
    # Use a default comment if one was not provided
    if [ -z "$comment" ]; then
      comment="<no desc>"
    fi

    # Create info file in the snapshot directory
    sourcedevice=$(findmnt -n -o SOURCE /)
    uuid=$(blkid -s UUID -o value "$sourcedevice")
    hostname=$(hostname -s)
    machine_id=$(cat /etc/machine-id)
    json=$(jq -nc --arg comment "$comment" --arg device "$sourcedevice" --arg uuid "$uuid" --arg hostname "$hostname" --arg machine_id "$machine_id" '{comment: $comment, device: $device, uuid: $uuid, hostname: $hostname, machine_id: $machine_id}')
    echo $json > "$path/$name/$g_infofile"

    # Done
    show "The snapshot '$name' was successfully completed."
  else
    show "Dry run complete"
  fi
}

check_rsync_perm() {
  local path=$1
  local device=$2

  local fstype
  local noperm

  fstype=$(lsblk --output MOUNTPOINTS,FSTYPE | grep "$path" | tr -s ' ' | cut -d ' ' -f2)
  echo "Backup device type is: $fstype" &>> "$g_logfile"
  case "$fstype" in
    "vfat"|"exfat")
      show "NOTE: The backup device '$device' is $fstype."
      noperm="--no-perms --no-owner"
      ;;
    "ntfs"|"ntfs3")
      # Permissions not found
      noperm="--no-perms --no-owner"
      ;;
    *)
      ;;
  esac

  if [ -n "$noperm" ]; then
    echo "Using options '$noperm' to prevent attempt to change ownership or permissions." &>> "$g_logfile"
  fi

  echo $noperm
}

cleanup() {
  unmount_device_at_path "$g_backuppath"
  [[ -n "$tail_pid" ]] && kill "$tail_pid" 2>/dev/null
}

# --------------------
# ------- MAIN -------
# --------------------

trap 'cleanup' EXIT

# Get the arguments
arg_short=dvc:
arg_long=dry-run,verbose,comment:
arg_opts=$(getopt --options "$arg_short" --long "$arg_long" --name "$0" -- "$@")
if [ $? != 0 ]; then
  show_syntax
  exit 1
fi

eval set -- "$arg_opts"
while true; do
  case "$1" in
    -d|--dry-run)
      dryrun=true
      shift
      ;;
    -c|--comment)
      comment="$2"
      shift 2
      ;;
    -v|--verbose)
      verbose=true
      shift
      ;;
    --) # End of options
      shift
      break
      ;;
    *)
      echo "Error parsing arguments: arg=$1"
      exit 1
      ;;
  esac
done

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

# Resolve source device info before mounting
sourcehostname=$(hostname -s)

minimum_space=5 # Amount in GB
snapshotname="$(date +%Y%m%d_%H%M%S)"

# Initialize the log file
g_logfile="/tmp/$(basename $0)_$snapshotname.log"
echo -n &> "$g_logfile"

# Start tailing if requested
if [[ -n "$verbose" ]]; then
  tail -f "$g_logfile" &
  tail_pid=$!
fi

mount_device_at_path "$backupdevice" "$g_backuppath" "$g_backupdir"

# Ensure the per-system hostname subdirectory exists
snapshotpath="$g_backuppath/$g_backupdir/$sourcehostname"
mkdir -p "$snapshotpath"

verify_available_space "$backupdevice" "$g_backuppath" "$minimum_space"
perm_opt=$(check_rsync_perm "$g_backuppath" "$backupdevice")
create_snapshot "$backupdevice" "$snapshotpath" "$snapshotname" "$comment" "$dryrun" "$perm_opt"

echo "✅ Backup complete: $snapshotpath/$snapshotname"
echo "Details of the operation can be viewed in the file '$g_logfile'"
