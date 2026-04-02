#!/usr/bin/env bash

# Deploy ts-tools to a target system.
# Copies library and program files to the target, then runs ts-install.sh remotely.
# Syntax: ts-deploy <target>
# Where:  <target> is the hostname or IP of the target system.

# Path to the global library files (from the tools repository)
TOOLS_DIR=~/src/mine/tools

# Global library files required by ts-tools (sourced from tools repository)
tools_lib_files=(
  device.sh
  display.sh
)

# Files to deploy
lib_files=(
  ts-shared.sh
)

prog_files=(
  ts-backup.sh
  ts-delete.sh
  ts-list.sh
  ts-restore.sh
  ts-install.sh
)

config_files=(
  ts-excludes
)

# --------------------
# ------- MAIN -------
# --------------------

if [ $# -lt 1 ]; then
  echo "Syntax: $(basename $0) <target>"
  exit 1
fi

target=$1
remote_user=rod
remote_home=/home/$remote_user

echo "Deploying ts-tools to $target..."

echo "Copying tools library files..."
for file in "${tools_lib_files[@]}"; do
  scp "$TOOLS_DIR/$file" "$remote_user@$target:$remote_home/$file"
  if [ $? -ne 0 ]; then
    echo "Error: Failed to copy $file to $target"
    exit 1
  fi
done

echo "Copying library files..."
for file in "${lib_files[@]}"; do
  scp "$file" "$remote_user@$target:$remote_home/$file"
  if [ $? -ne 0 ]; then
    echo "Error: Failed to copy $file to $target"
    exit 1
  fi
done

echo "Copying program files..."
for file in "${prog_files[@]}"; do
  scp "$file" "$remote_user@$target:$remote_home/$file"
  if [ $? -ne 0 ]; then
    echo "Error: Failed to copy $file to $target"
    exit 1
  fi
done

echo "Copying config files..."
for file in "${config_files[@]}"; do
  scp "$file" "$remote_user@$target:$remote_home/$file"
  if [ $? -ne 0 ]; then
    echo "Error: Failed to copy $file to $target"
    exit 1
  fi
done

echo "Running ts-install.sh on $target..."
ssh -t "$remote_user@$target" "bash $remote_home/ts-install.sh"
if [ $? -ne 0 ]; then
  echo "Error: Installation failed on $target"
  exit 1
fi

echo "✅ ts-tools deployment to $target complete."
