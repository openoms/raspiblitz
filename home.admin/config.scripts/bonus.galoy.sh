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
  ################
  # Dependencies
  ################
  # https://github.com/GaloyMoney/charts/blob/main/charts/galoy/Chart.yaml

  # NodeJS
  /home/admin/config.scripts/bonus.nodejs.sh on

  # Docker
  /home/admin/config.scripts/blitz.docker.sh on

  # direnv
  if ! dpkg --list | grep direnv; then
    sudo apt-get update
    sudo apt-get install -y direnv
  fi

  # Yarn
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

  # redis
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

  ## MongoDB - using the Docker image
  #https://github.com/bitnami/charts/tree/master/bitnami/mongodb#mongodb-parameters
  # 4.4.11-debian-10-r12

  #############################
  # User, symlinks, permissions
  #############################
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

  ################
  # Installation
  ################
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

  # sudo -u galoy make start-sh-deps
  sudo -u galoy make start-sh
  # docker compose down
  # sudo -u galoy make reset-sh-deps

  ##############
  # Connections
  ##############
  # setup nginx symlinks
  # http://localhost:4000/graphql (old API - deprecated)
  # http://localhost:4001/graphql (admin API)
  # http://localhost:4002/graphql (new API)
  # galoy-admin-API_ssl
  if ! [ -f /etc/nginx/sites-available/galoy-admin-API_ssl.conf ]; then
    sudo cp /home/admin/assets/galoy/galoy-admin-API_ssl.conf /etc/nginx/sites-available/galoy-admin-API_ssl.conf
  fi
  sudo ln -sf /etc/nginx/sites-available/galoy-admin-API_ssl.conf /etc/nginx/sites-enabled/

  # galoy-API_ssl
  if ! [ -f /etc/nginx/sites-available/galoy-API_ssl.conf ]; then
    sudo cp /home/admin/assets/galoy/galoy-API_ssl.conf /etc/nginx/sites-available/galoy-API_ssl.conf
  fi
  sudo ln -sf /etc/nginx/sites-available/galoy-API_ssl.conf /etc/nginx/sites-enabled/

  sudo nginx -t || exit 1
  sudo systemctl reload nginx

  sudo ufw allow 4011 comment "galoy-admin-API_ssl"
  sudo ufw allow 4012 comment "galoy-API_ssl"

  # Tor not active as there is no password protection
  # /home/admin/config.scripts/tor.onion-service.sh galoy-admin-api 80 4001

  localIP=$(hostname -I)
  echo "# Connect to the Galoy admin API on: https://${localIP}:4011/graphql"
  echo "# Connect to the Galoy API on: https://${localIP}:4012/graphql"
fi

# https://github.com/GaloyMoney/web-wallet
if [ "$1" = "web-wallet" ]; then
  echo
  echo "# Build web-wallet"
  cd /home/galoy/ || exit 1
  sudo -u galoy git clone https://github.com/GaloyMoney/web-wallet
  cd web-wallet || exit 1

  # copy edited .envrc
  sudo -u galoy cp /home/admin/raspiblitz/home.admin/assets/galoy/web-wallet-env ./.envrc

  # dependencies
  sudo -u galoy docker compose up
  # https://github.com/GaloyMoney/web-wallet#how-to-run-this-repo-locally
  sudo -u galoy yarn install
  # In another terminal
  sudo -u galoy yarn dev:server

  # galoy-web-wallet_ssl
  if ! [ -f /etc/nginx/sites-available/galoy-web-wallet_ssl.conf ]; then
    sudo cp /home/admin/assets/galoy/galoy-web-wallet_ssl.conf /etc/nginx/sites-available/galoy-web-wallet_ssl.conf
  fi
  sudo ln -sf /etc/nginx/sites-available/galoy-web-wallet_ssl.conf /etc/nginx/sites-enabled/
  sudo nginx -t || exit 1
  sudo systemctl reload nginx
  sudo ufw allow 4031 comment "galoy-web-wallet_ssl"
  echo "# Connect to the web-wallet on: https://$(hostname -I):4031/graphql"
fi

# price
# build Docker image from the source - downloaded by default
if [ "$1" = "price" ]; then
  echo
  echo "# Build galoy-price"
  cd /home/galoy/ || exit 1
  sudo -u galoy git clone https://github.com/GaloyMoney/price.git
  cd price || exit 1
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

  docker compose down

  sudo ufw deny 4011
  sudo ufw deny 4012
  # /home/admin/config.scripts/tor.onion-service.sh off galoy-admin-api
  sudo rm /etc/nginx/sites-available/galoy-admin-API_ssl.conf
  sudo rm /etc/nginx/sites-available/galoy-API_ssl.conf

  # web-wallet
  sudo ufw deny 4031
  sudo rm /etc/nginx/sites-available/galoy-web-wallet_ssl.conf

  sudo nginx -t || exit 1
  sudo systemctl reload nginx
  sudo userdel -rf galoy

fi
