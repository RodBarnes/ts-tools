# CLAUDE.md — ts-tools

## Project Overview

**ts-tools** is a bash-based snapshot backup suite for headless Debian-based Linux servers, emulating Timeshift behavior without its GUI dependencies. It uses `rsync` with hard-link-based incremental snapshots.

Scripts: `ts-backup`, `ts-restore`, `ts-list`, `ts-delete`, `ts-shared`.

Development is done on a local machine. Deployment to target servers uses `ts-deploy.sh`, which copies files via `scp` and runs `ts-install.sh` remotely via `ssh -t rod@<target>`.

Target servers: **boss** (Debian 13, Docker, Nextcloud/Home Assistant) and **shrek** (Debian 13, Docker, Caddy/Pi-hole). Remote user is `rod`.

---

## Coding Standards

### `local` Variable Declarations

- Declare **one variable per line** — never collapse multiple declarations onto one line.
- Always declare `local` variables **at the top of the function**, before any logic. Bash has no block scoping.
- **Never combine `local` with command substitution** — this masks the exit code of the subshell.

```bash
# CORRECT
local result
result=$(some_command)
if [ $? -ne 0 ]; then ...

# WRONG — exit code of some_command is lost
local result=$(some_command)
```

### Quoting

- Quote all variable expansions unless intentionally word-splitting.
- Known exceptions: `$perm_opt` and `$dryrun_flag` are passed unquoted intentionally so they expand to nothing (not an empty string) when unset.

### sudo and I/O Redirection

- `sudo` does not elevate shell-level I/O redirection operators (`>`, `>>`).
- Use the `sudo tee` pattern for writing to privileged paths:

```bash
# CORRECT
echo "$content" | sudo tee /privileged/path > /dev/null

# WRONG — redirection runs as the calling user, not root
sudo echo "$content" > /privileged/path
```

### Functions

- Functions belong in `ts-shared.sh` **only if actually used by more than one script**.
- Do not preemptively move functions to the shared library in anticipation of future reuse.
- Keep script-specific functions in the script that uses them.

---

## Architecture Conventions

### Directory Structure

Snapshots are stored under a hostname-based subdirectory:

```
<backup_mount>/
  ts/
    <hostname>/
      <timestamp>/          # e.g., 20250401_143022
        info.json
        ...snapshot files...
```

Hostname is used for subdirectory paths (human-readable, stable). `/etc/machine-id` is the authoritative per-machine identity used for restore verification.

### Snapshot Naming

Snapshot directories are named by timestamp: `YYYYMMDD_HHMMSS`. The `find` and `grep` filters use `^[0-9]{8}_[0-9]{6}$` to identify valid snapshot directories.

### Incremental Snapshots

- The first snapshot is a full rsync of `/`.
- Subsequent snapshots use `--link-dest` pointing to the most recent snapshot, creating hard-linked incrementals.
- The most recent snapshot is identified by sorting timestamp directory names and taking the last.

### info.json

Generated with `jq -nc`. Fields must be exactly:

```json
{
  "comment": "...",
  "device": "...",
  "uuid": "...",
  "hostname": "...",
  "machine_id": "..."
}
```

Example generation pattern:
```bash
json=$(jq -nc \
  --arg comment "$comment" \
  --arg device "$device" \
  --arg uuid "$uuid" \
  --arg hostname "$hostname" \
  --arg machine_id "$machine_id" \
  '{comment: $comment, device: $device, uuid: $uuid, hostname: $hostname, machine_id: $machine_id}')
echo "$json" > "$path/$name/$g_infofile"
```

### select_snapshot Return Value

`select_snapshot` returns a string in the form `hostname/snapshotname` (e.g., `boss/20250401_143022`). Callers **must split** this before use:

```bash
snapshotpath="$g_backuppath/$g_backupdir/${snapshotsubpath%/*}"
snapshotname="${snapshotsubpath##*/}"
```

### Device Resolution at Restore

- The restore target device is resolved from the UUID stored in `info.json` using `blkid -U "$uuid"`.
- Machine identity is verified by comparing `machine_id` from `info.json` against `/etc/machine-id`. A mismatch produces a warning prompt, not a hard abort.

### Excludes File

- `ts-excludes` is deployed to `/etc/ts-excludes` on target systems.
- Referenced via `g_excludesfile="/etc/ts-excludes"` in `ts-shared.sh`.
- If the excludes file is missing at backup or restore time, the user is prompted whether to proceed without exclusions.

### Boot Rebuild (ts-restore)

`ts-restore` includes grub/EFI boot rebuild logic invoked after a restore:

- `get_bootfile` — detects Secure Boot status via EFI variables and sets `g_bootfile` (`grubx64.efi` default, `shimx64.efi` if Secure Boot enabled).
- `validate_boot_config` — checks restored partition for expected boot components; prompts for a boot device if configuration appears invalid.
- `build_boot` — chroots into the restored partition, runs `grub-install` and `update-grub`, and ensures a UEFI boot entry exists via `efibootmgr`.
- `g_bootfile` is initialized in `ts-shared.sh` to `grubx64.efi` and may be overridden by `get_bootfile`.
- Boot rebuild is skipped during dry-run.

### Filesystem Type and Permissions

`check_rsync_perm` detects the backup device filesystem type. For `vfat`, `exfat`, `ntfs`, and `ntfs3`, `--no-perms --no-owner` flags are added to the rsync command. The result is stored in `$perm_opt` and passed unquoted to rsync so it expands to nothing when empty.

---

## Shared Libraries

`display.sh` and `device.sh` live in a **separate repository** (`tools`) and are deployed independently to `/usr/local/lib`. Do not modify or duplicate them in this project. They are sourced by `ts-shared.sh`:

```bash
source /usr/local/lib/display.sh
source /usr/local/lib/device.sh
```

---

## Deployment Pattern

- `ts-deploy.sh` copies files from the dev machine to `rod@<target>:~` via `scp`, then invokes `ts-install.sh` remotely via `ssh -t rod@<target>`.
- `ts-install.sh` installs files as root:
  - `ts-shared.sh` → `/usr/local/lib/`
  - Executable scripts → `/usr/local/sbin/` with `.sh` extension stripped
  - `ts-excludes` → `/etc/ts-excludes`
- `ssh -t` is required for TTY allocation when sudo prompts are expected.

---

## External Dependencies

The following tools must be present on target systems:

| Tool | Purpose |
|------|---------|
| `rsync` | Snapshot creation and restore |
| `jq` | info.json generation and parsing |
| `blkid` | UUID-based device resolution |
| `findmnt` | Active root partition detection |
| `lsblk` | Filesystem type detection |
| `efibootmgr` | UEFI boot entry management (restore) |
| `grub-install` | Boot rebuild (restore) |
| `update-grub` | Boot rebuild (restore) |
