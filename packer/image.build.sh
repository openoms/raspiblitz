#!/bin/sh -eux

echo 'nameserver 1.1.1.1' > /etc/resolv.conf
echo 'nameserver 8.8.8.8' >> /etc/resolv.conf
echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
apt-get update
apt-get upgrade -y
apt-get install -y sudo wget
apt-get -y autoremove
apt-get -y clean

# run the build script
../test.sh