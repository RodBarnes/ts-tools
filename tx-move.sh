#!/usr/bin/env bash

sudo chown root:root ts-shared.sh
sudo mv ts-shared.sh /usr/local/lib

sudo chown root:root ts-*.sh
sudo chmod +x ts-*.sh
for file in ts-*.sh; do
	sudo mv "$file" "/usr/local/bin/${file%.sh}"
done


sudo bash tx-sha256.sh
rm tx-sha256.sh
rm tx-move.sh
