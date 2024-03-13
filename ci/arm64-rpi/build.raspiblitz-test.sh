#!/bin/sh -eux

# make /dev/shm world writable for qemu
sudo chmod 777 /dev/shm

# make /var/cache/raspiblitz world writable for qemu
sudo chmod 777 /var/cache/raspiblitz

echo '# Check out the branch of the PR (passed down as an env variable)'
/home/admin/config.scripts/blitz.github.sh ${branch} ${github_user}

echo '# Test the installs'

command="/home/admin/config.scripts/bonus.jam.sh on"
echo "# Running: ${command}"
${command}
