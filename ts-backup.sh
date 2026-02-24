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
  local device=$1 path=$2 minspace=$3

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
  local device=$1 path=$2 name=$3 note=$4 dry=$5 perm=$6

  if [[ -n "$perm" ]]; then
    show "The backup device does not support permmissions or ownership."
    show "The rsync will be performed without attempting to set these options."
  fi

  # Get the name of the most recent backup
  local latest=$(ls -1 "$path" | grep -E '^[0-9]{8}_[0-9]{6}_.+$' | sort -r | sed -n '1p;')
  local type

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
  local used_before
  used_before=$(df "$path" --output=used -BK | tail -1 | tr -d 'K')

  if [ -n "$latest" ]; then
    show "Creating incremental snapshot on '$device'..."
    type="incr"
    # Snapshots exist so create incremental snapshot referencing the latest
    echo "rsync -aAX $dryrun_flag $perm --verbose --delete --link-dest=\"$g_backuppath/$g_backupdir/$latest\" $excludearg / \"$path/$name/\"" &>> "$g_logfile"
    rsync -aAX $dryrun_flag $perm --verbose --delete --link-dest="$g_backuppath/$g_backupdir/$latest" $excludearg / "$path/$name/" &>> "$g_logfile"
  else
    show "Creating full snapshot on '$device'..."
    type="full"
    # This is the first snapshot so create full snapshot
    echo "rsync -aAX $dryrun_flag $perm --verbose --delete $excludearg / \"$path/$name/\"" &>> "$g_logfile"
    rsync -aAX $dryrun_flag $perm --verbose --delete $excludearg / "$path/$name/" &>> "$g_logfile"
  fi

  if [ -z "$dry" ]; then
    # Use a default comment if one was not provided
    if [ -z "$note" ]; then
      note="<no desc>"
    fi

    # Calculate actual space consumed by this snapshot (hard links don't add blocks,
    # so the df delta reflects only the new unique files written by this snapshot)
    local used_after delta_kb snapshot_size
    used_after=$(df "$path" --output=used -BK | tail -1 | tr -d 'K')
    delta_kb=$(( used_after - used_before ))
    if (( delta_kb >= 1048576 )); then
      snapshot_size="$(( delta_kb / 1048576 ))G"
    elif (( delta_kb >= 1024 )); then
      snapshot_size="$(( delta_kb / 1024 ))M"
    else
      snapshot_size="${delta_kb}K"
    fi

    # Create comment in the snapshot directory
    echo "($type $snapshot_size) $note" > "$path/$name/$g_descfile"

    # Done
    show "The snapshot '$name' was successfully completed."
  else
    show "Dry run complete"
  fi
}

check_rsync_perm() {
  local path=$1 device=$2

  unset noperm
  local fstype=$(lsblk --output MOUNTPOINTS,FSTYPE | grep "$path" | tr -s ' ' | cut -d ' ' -f2)
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

minimum_space=5 # Amount in GB
snapshotname="$(date +%Y%m%d_%H%M%S)_$(hostname -s)"

# Initialize the log file
g_logfile="/tmp/$(basename $0)_$snapshotname.log"
echo -n &> "$g_logfile"

# Start tailing if requested
if [[ -n "$verbose" ]]; then
  tail -f "$g_logfile" &
  tail_pid=$!
fi

mount_device_at_path  "$backupdevice" "$g_backuppath" "$g_backupdir"

verify_available_space "$backupdevice" "$g_backuppath" "$minimum_space"
perm_opt=$(check_rsync_perm "$g_backuppath" "$backupdevice")
create_snapshot "$backupdevice" "$g_backuppath/$g_backupdir" "$snapshotname" "$comment" "$dryrun" "$perm_opt"

echo "✅ Backup complete: $g_backuppath/$g_backupdir/$snapshotname"
echo "Details of the operation can be viewed in the file '$g_logfile'"