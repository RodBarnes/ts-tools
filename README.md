# ts-tools
A collection of `bash` scripts that emulate TimeShift backups on headless systems.

This requires `rsync` be installed as well as expecting the `display` and `device` libraries (found in the [tools](https://github.com/RodBarnes/tools) repository) be in `/usr/local/lib`.

These are written for bash on debian-based distros.  They may work as is or should be easily modified to work on other distros.

NOTE: Yes, TimeShift provides a command line but TimeShift includes all the GUI dependicies even if they aren't required on a headless system.  Plus, this was a fun project.

## ts-backup.sh
Usage: `sudo ts-backup <backup_device> [-d|--dry-run] [-c|--comment "comment"]`

Creates a full or incrental snapshot on the `backup_device` of the current active partition from which it is run.

## ts-delete.sh
Usage: `sudo ts-delete <backup_device>`

Lists the `ts-backup` snapshots found on the designated device and allows selecting one for deletion.

## ts-excludes
Place this file in `/etc`.  It is used by `ts-backup` and `ts-restore` to ignore specific directories and files.  As provided, it matches what TimeShift excludes as of v25.07.7.

## ts-list.sh
Usage: `sudo ts-list <backup_device>`

Lists the `ts-backup` snapshots found on the designated device.

## ts-restore.sh
Usage: `sudo ts-restore <backup_device> <restore_device> [-d|--dry-run] [-g|--grub-install boot_device] [-s|--snapshot snapshot_name]`

Restores a `ts-backup` snapshot from the `backup_device` to the `restore_device`.

**This is best run from a server's recovery partition or a live image.**  Some inconsistencies may result from an in-place restore to the active partition.  (It has been tested under both situations and works, but...)

## ts-shared.sh
Shared functions and variables used by `ts-tools`.  This is accessed by the other programs and is expected to be in `/usr/local/lib`.
