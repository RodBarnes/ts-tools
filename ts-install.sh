#!/usr/bin/env bash

# Install ts-tools on the local system.
# Intended to be copied to the target and invoked remotely by ts-deploy.sh.
# Must be run as a user with sudo privileges.

lib_dest=/usr/local/lib
sbin_dest=/usr/local/sbin
remote_home=/home/rod

lib_files=(
  ts-shared.sh
  device.sh
  display.sh
)

prog_files=(
  ts-backup.sh
  ts-delete.sh
  ts-list.sh
  ts-restore.sh
)

config_files=(
  ts-excludes
)

echo "Installing ts-tools..."

sudo -v || exit 1

echo "Installing required packages..."
sudo apt-get install -y rsync jq
if [ $? -ne 0 ]; then
  echo "Error: Failed to install required packages"
  exit 1
fi

echo "Installing library files to $lib_dest..."
for file in "${lib_files[@]}"; do
  sudo chown root:root "$remote_home/$file"
  sudo mv "$remote_home/$file" "$lib_dest/$file"
  if [ $? -ne 0 ]; then
    echo "Error: Failed to install $file to $lib_dest"
    exit 1
  fi
done

echo "Installing program files to $sbin_dest..."
for file in "${prog_files[@]}"; do
  target="${file%.sh}"
  sudo chown root:root "$remote_home/$file"
  sudo chmod +x "$remote_home/$file"
  sudo mv "$remote_home/$file" "$sbin_dest/$target"
  if [ $? -ne 0 ]; then
    echo "Error: Failed to install $file to $sbin_dest"
    exit 1
  fi
done

echo "Installing config files to /etc..."
for file in "${config_files[@]}"; do
  sudo chown root:root "$remote_home/$file"
  sudo mv "$remote_home/$file" "/etc/$file"
  if [ $? -ne 0 ]; then
    echo "Error: Failed to install $file to /etc"
    exit 1
  fi
done

echo "Cleaning up..."
rm -f "$remote_home/ts-install.sh"

echo "✅ ts-tools installation complete."
