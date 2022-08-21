#!/bin/bash -e

# Install packer
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update
echo -e "\nInstalling packer..."
sudo apt-get install -y packer

# Build the image
echo -e "\nBuilding image..."
cd debian
PACKER_LOG=1 packer build -only=virtualbox-iso debian-11.4-amd64.json
