#!/bin/sh -eux

if [ "${fatpack}" = "true" ]; then
  echo 'Add Gnome desktop'
  export DEBIAN_FRONTEND=none
  sudo apt install gnome -y
fi

echo 'Download the build_sdcard.sh script ...'
wget https://raw.githubusercontent.com/${github_user}/raspiblitz/${branch}/build_sdcard.sh


if [ "${pack}" = lean ]; then
  fatpack=0
elif [ "${pack}" = fatpack ]; then
  fatpack=1
else
  fatpack=0
fi

echo 'Build RaspiBlitz ...'
sudo bash build_sdcard.sh -f ${fatpack} -u ${github_user} -b ${branch} -d headless -t false -w off -i false
