#!/bin/bash

# command info
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "-help" ]; then
  echo "config script to install the Galoy stack"
  echo "bonus.galoy.sh [on|off|web-wallet|price|test]"
  echo "installs the latest main by default"
  exit 1
fi

# install
if [ "$1" = "on" ]; then

  # https://github.com/GaloyMoney/galoy/blob/main/DEV.md#setup
  /home/admin/config.scripts/bonus.nodejs.sh on
  /home/admin/config.scripts/blitz.docker.sh on

  if ! dpkg --list | grep direnv; then
    sudo apt-get update
    sudo apt-get install -y direnv
  fi

  if dpkg --list | grep yarg; then
    echo "# Yarn is already installed"
    yarn --version
  else
    echo "# Install Yarn"
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
    sudo apt-get update
    sudo apt-get install -y yarn
  fi

  # Dependencies:
  # https://github.com/GaloyMoney/galoy/blob/main/DEV.md#setup
  # https://github.com/GaloyMoney/charts/blob/main/charts/galoy/Chart.yaml

  # # redis
  # https://github.com/bitnami/charts/tree/master/bitnami/redis#redis-image-parameters
  # 6.2.6-debian-10-r142

  if [ $(redis-cli --version | grep -c "6.2.6") -lt 1 ]; then
    if ! gpg  /usr/share/keyrings/redis-archive-keyring.gpg 2>/dev/null; then
      curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
    fi
    echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list
    sudo apt-get update
    sudo apt-get install -y redis #install the new config
  else
    echo "# Redis is already installed"
    redis-cli --version
  fi

  ## MongoDB
  #https://github.com/bitnami/charts/tree/master/bitnami/mongodb#mongodb-parameters
  # 4.4.11-debian-10-r12
  # using Docker

  echo
  echo "# Create user and symlinks"
  sudo adduser --disabled-password --gecos "" galoy
  # passwordless access to sudo
  sudo adduser galoy sudo

  # add the user to the docker group
  sudo usermod -aG docker galoy

  # symlink to the lnd data directory exists"
  sudo rm -rf /home/galoy/.lnd  # not a symlink.. delete it silently
  # create symlink
  sudo ln -s "/home/bitcoin/.lnd/" "/home/galoy/.lnd"
  sudo chmod -R 750 /home/galoy/.lnd/
  sudo /usr/sbin/usermod --append --groups lndadmin galoy
  sudo /usr/sbin/usermod --append --groups bitcoin galoy

  echo "# Clone galoy"
  cd /home/galoy/ || exit 1
  sudo -u galoy git clone https://github.com/GaloyMoney/galoy
  cd galoy || exit 1
  sudo -u galoy direnv allow
  # https://github.com/grpc/grpc-node/issues/1405
  sudo npm install -g grpc-tools  --target_arch=x64
  sudo -u galoy yarn install --ignore-scripts

  sudo -u galoy cp /home/admin/raspiblitz/home.admin/assets/galoy/.envrc ./
  sudo -u galoy cp /home/admin/raspiblitz/home.admin/assets/galoy/docker-compose.yml ./
  sudo -u galoy cp /home/admin/raspiblitz/home.admin/assets/galoy/Makefile ./

  sudo -u galoy make start-sh-deps
  # sudo -u galoy make start-sh
  # docker compose down
  # sudo -u galoy make reset-sh-deps


  sudo ufw allow 4000 comment "Galoy old API - deprecated)"
  sudo ufw allow 4001 comment "Galoy admin API"
  sudo ufw allow 4002 comment "Galoy new API"
  # http://localhost:4000/graphql (old API - deprecated)
  # http://localhost:4001/graphql (admin API)
  # http://localhost:4002/graphql (new API)

  # /home/admin/config.scripts/tor.onion-service.sh galoy-admin-api 80 4001

fi

# https://github.com/GaloyMoney/web-wallet
if [ "$1" = "web-wallet" ]; then
  echo
  echo "# Build web-wallet"
  cd /home/galoy/ || exit 1
  sudo -u galoy git clone https://github.com/GaloyMoney/web-wallet
  cd web-wallet || exit 1
  # https://github.com/GaloyMoney/web-wallet#how-to-run-this-repo-locally
  sudo -u galoy yarn install
  # In another terminal
  sudo -u galoy yarn dev:server

  docker compose up

  # copy edited .envrc
  # sudo -u galoy cp /home/admin/raspiblitz/home.admin/assets/galoy/web-wallet-.envrc ./.envrc

fi

# price
# build Docker image from the source - downloaded by default
if [ "$1" = "price" ]; then
  echo
  echo "# Build galoy-price"
  cd /home/galoy/ || exit 1
  sudo -u galoy git clone https://github.com/GaloyMoney/price.git
  cd price
  sudo -u galoy docker build -f ./realtime/Dockerfile -t galoy-price .
  sudo -u galoy docker run galoy-price
fi

# test
if [ "$1" = "test" ]; then
  cd /home/galoy/galoy || exit 1
  sudo systemctl stop redis-server
  sudo systemctl stop mongod
  sudo systemctl stop lnd
  TEST="01|02" make reset-integration
fi

if [ "$1" = "off" ]; then
  sudo userdel -rf galoy
fi
