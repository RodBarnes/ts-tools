#!/usr/bin/env bash

# Get the arguments
guid_regex="^\S{8}-\S{4}-\S{4}-\S{4}-\S{12}$"
ntfs_uuid_regex="^\S{16}$"
fat_uuid="^\S{4}-\S{4}$"
if [ $# -ge 1 ]; then
  arg="$1"
  shift 1
  backupdevice="/dev/$(lsblk -ln -o NAME,UUID,PARTUUID,LABEL | grep "$arg" | tr -s ' ' | cut -d ' ' -f1)"
else
  echo "You must provice a device."
  exit 1
fi

if [[ ! -b "$backupdevice" ]]; then
  echo "Error: The specified backup device '$backupdevice' is not a block device."
  exit 2
fi

echo "Success: $backupdevice"
