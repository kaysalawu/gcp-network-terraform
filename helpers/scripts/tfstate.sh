#!/bin/bash

root_dir="$HOME/GCP/gcp-network-terraform"
dest_dir="$HOME/TFSTATE"

echo "Scanning from root_dir: $root_dir"

find "$root_dir" -type f -name "terraform.tfstate" | while read -r tfstate_file; do
    relative_path=$(dirname "${tfstate_file#$root_dir/}")
    mkdir -p "$dest_dir/$relative_path"
    cp "$tfstate_file" "$dest_dir/$relative_path/"
    echo "Copy: ${tfstate_file#$root_dir/} --> $dest_dir/$relative_path/"
done

script_path="$HOME/GCP/gcp-network-terraform/helpers/scripts/tfstate.sh"
sudo bash -c "cat <<EOF > /etc/cron.d/tfstate-backup
*/5 * * * * . $script_path 2>&1 > /dev/null
EOF"
crontab /etc/cron.d/tfstate-backup


