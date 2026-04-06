# ts-tools
## General
A collection of `bash` scripts that emulate TimeShift backups on headless systems.  They are written for bash on debian-based distros.  They may work as is or should be easily modified to work on other distros.

### Installation
To install these tools on a server, run `bash ./ts-deploy.sh <hostname>`.  It will copy the files to the server and install them in `/usr/local/sbin` and `/usr/local/lib`.  It will also install the required dependencies  `rsync` and `jq` and the [display.sh](https://github.com/RodBarnes/tools/blob/main/display.sh) and [device.sh](https://github.com/RodBarnes/tools/blob/main/device.sh) libraries (found in the [tools](https://github.com/RodBarnes/tools) repository).

To install on the local system, run `bash ./ts-install.sh --local`.

For all the tools `<backup_device>` can be a device designator (e.g., /dev/sdb6), a UUID, or filesystem LABEL.

NOTE: Yes, TimeShift provides a command line but TimeShift includes all the GUI dependicies even if they aren't required on a headless system.  Plus, this was a fun project.

### .git/hooks/pre-commit
A Git pre-commit hook is included that automatically updates the `VERSION` variable in any staged script file (and `TS_SHARED_VERSION` in `ts-shared.sh`) to the current date (`YYYYMMDD`) at commit time.

After a fresh clone, install it manually:
```bash
cp git_hooks_pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

## ts-backup.sh
Usage: `sudo ts-backup <backup_device> [-d|--dry-run] [-c|--comment "comment"] [-v|--verbose] [-V|--version]`

Creates a full or incremental snapshot on the `backup_device` of the current active partition from which it is run.

## ts-delete.sh
Usage: `sudo ts-delete <backup_device> [-V|--version]`

Lists the `ts-backup` snapshots found on the designated device and allows selecting one for deletion.

## ts-excludes
Place this file in `/etc`.  It is used by `ts-backup` and `ts-restore` to ignore specific directories and files.  As provided, it matches what TimeShift excludes as of v25.07.7.

## ts-list.sh
Usage: `sudo ts-list <backup_device> [-V|--version]`

Lists the `ts-backup` snapshots found on the designated device.

## ts-restore.sh
Usage: `sudo ts-restore <backup_device> [-d|--dry-run] [-g|--grub-install boot_device] [-s|--snapshot snapshot_name] [-v|--verbose] [-V|--version]`

Restores a `ts-backup` snapshot from the `backup_device` to the `restore_device`.

**This is best run from a server's recovery partition or a live image.**  Some inconsistencies may result from an in-place restore to the active partition.  (It has been tested under both situations and works, but...)

## ts-shared.sh
Shared functions and variables used by `ts-tools`.  This is accessed by the other programs and is expected to be in `/usr/local/lib`.

