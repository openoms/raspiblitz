#!/bin/bash -e

sudo apt install -y \
  wget \
  curl \
  ca-certificates \
  dosfstools \
  fdisk \
  gdisk \
  kpartx \
  libarchive-tools \
  parted \
  psmisc \
  qemu-utils \
  sudo \
  xz-utils \
  qemu-user-static

# Install packer
echo -e "\nInstalling Packer..."
if ! packer version; then
  curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
  sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
  sudo apt-get update -y && sudo apt-get install packer -y
else
  echo "Packer is installed"
fi

echo -e "Installing Go..."
export PATH=$PATH:/usr/local/go/bin
if ! go version | grep "1.18.9"; then
  wget --progress=bar:force https://go.dev/dl/go1.18.9.linux-amd64.tar.gz
  echo "015692d2a48e3496f1da3328cf33337c727c595011883f6fc74f9b5a9c86ffa8 go1.18.9.linux-amd64.tar.gz" | sha256sum -c -
  sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.18.9.linux-amd64.tar.gz
  sudo rm -rf go1.18.9.linux-amd64.tar.gz
else
  echo "Go 1.18.9 is installed"
fi

# Install Packer Arm Plugin
echo -e "\nInstalling Packer Arm Plugin..."
if ! [ -d packer-builder-arm ]; then
  git clone https://github.com/mkaczanowski/packer-builder-arm
fi
cd packer-builder-arm
# pin to commit hash https://github.com/mkaczanowski/packer-builder-arm/commits/master
git reset --hard 6636c687ece53f7d1f5f2b35aa41f0e6132949c4
go mod download
go build

if [ $# -gt 0 ]; then
  pack=$1
else
  pack=lean
fi

if [ $# -gt 1 ]; then
  github_user=$2
else
  github_user=rootzoll
fi

if [ $# -gt 2 ]; then
  branch=$3
else
  branch=dev
fi

cp ../arm64-rpi.pkr.hcl ./
cp ../raspiblitz.sh ./

echo -e "\nBuild Packer image..."
packer build -var github_user=${github_user} -var branch=${branch} -var pack=${pack} arm64-rpi.pkr.hcl
