#!/usr/bin/env bash

sudo chown root:root ts_shared.sh
sudo mv ts_shared.sh /usr/local/lib

sudo chown root:root ts_*.sh
sudo chmod +x ts_*.sh
for file in ts_*.sh; do
	sudo mv "$file" "/usr/local/bin/${file%.sh}"
done
