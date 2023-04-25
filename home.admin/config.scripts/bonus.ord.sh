#!/bin/bash

# https://github.com/romanz/ord/releases
ordVERSION="v0.9.11"
# https://github.com/romanz/ord/commits/master
# ordVERSION="446858ea621416916f84cbce61be92b748e8133e"

# command info
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "-help" ]; then
 echo "config script to switch the Electrum Rust Server on or off"
 echo "bonus.ord.sh status -> dont call in loops"
 echo "bonus.ord.sh status-sync"
 echo "bonus.ord.sh [on|off|menu|update]"
 echo "installs the version $ordVERSION"
 exit 1
fi

PGPsigner="romanz"
PGPpubkeyLink="https://github.com/${PGPsigner}.gpg"
PGPpubkeyFingerprint="87CAE5FA46917CBB"

source /mnt/hdd/raspiblitz.conf


# switch on
if [ "$1" = "1" ] || [ "$1" = "on" ]; then
  echo "# INSTALL ord"

  isInstalled=$(sudo ls /etc/systemd/system/ord.service 2>/dev/null | grep -c 'ord.service')
  if [ ${isInstalled} -eq 0 ]; then


## INSTALLL
# https://github.com/casey/ord#installation

# system dependencies
sudo apt-get install libssl-dev gcc

# create user
sudo adduser --disabled-password --gecos "" ord
# switch to user
sudo su - ord
# install rust for the user
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"
# download source
git clone https://github.com/casey/ord.git
cd ord
# build
cargo build --release

# prepare the data directory
# exit user
exit
sudo mkdir /mnt/hdd/app-storage/ord
sudo chown -R ord:ord /mnt/hdd/app-storage/ord

# prepare bitcoind (apps realying on rpcuser and rpcpassword auth will stop working)
# comment out rpcuser and rpcpassword in bitcoin.conf
sudo sed -i "s/^rpcuser/#rpcuser/g" /mnt/hdd/bitcoin/bitcoin.conf
sudo sed -i "s/^rpcpassword/#rpcpassword/g" /mnt/hdd/bitcoin/bitcoin.conf
# restart bitcoind
sudo systemctl restart bitcoind
# make the .cookie file group readable
sudo chmod 640 /mnt/hdd/bitcoin/.cookie
# add the ord user to the bitcoin group
sudo usermod -a -G bitcoin ord

sudo mkdir /mnt/hdd/app-storage/ord
sudo chown -R ord:ord /mnt/hdd/app-storage/ord

# Build the ord database
# switch to user
sudo su - ord

# run ord (in tmux) to create the database
./ord/target/release/ord \
  --cookie-file /mnt/hdd/bitcoin/.cookie \
  --data-dir /mnt/hdd/app-storage/ord \
  --bitcoin-data-dir /mnt/hdd/bitcoin \
  --rpc-url 127.0.0.1:8330 \
  --index-sats \
  index



## Configure apps to use the rpc cookie

## Mempool works ok
## CLN works ok
## LND works ok

# comment out bitcoin.rpcpassword and bitcoin.rpcuser in lnd.conf
sudo sed -i "s/^bitcoin.rpcpassword/#bitcoin.rpcpassword/g" /mnt/hdd/lnd/lnd.conf
sudo sed -i "s/^bitcoin.rpcuser/#bitcoin.rpcuser/g" /mnt/hdd/lnd/lnd.conf

# add bitcoind.rpccookie=/mnt/hdd/bitcoin/.cookie under the header [bitcoind] in lnd.conf
sudo sed -i '/^\[bitcoind\]/a bitcoin.cookiefile=/path/to/.cookie' /mnt/hdd/lnd/lnd.conf

# make the .cookie file group readable
sudo chmod 640 /mnt/hdd/bitcoin/.cookie

# move lnd.check.sh to lnd.check.sh.bak
mv /home/admin/config.scripts/lnd.check.sh /home/admin/config.scripts/lnd.check.sh.bak

# restart lnd
sudo systemctl restart lnd

getting
```
error creating wallet config: unable to create partial chain control: status code: 401, response: ""
```

## Fulcrum
sudo usermod -a -G bitcoin fulcrum
#comment out rpcuser and rpcpassword in fulcrum.conf
sudo sed -i "s/^rpcuser/#rpcuser/g" /home/fulcrum/.fulcrum/fulcrum.conf
sudo sed -i "s/^rpcpassword/#rpcpassword/g" /home/fulcrum/.fulcrum/fulcrum.conf
# add the rpccookie option
if ! grep -q "^rpccookie" /home/fulcrum/.fulcrum/fulcrum.conf; then
  echo "rpccookie=/mnt/hdd/bitcoin/.cookie" | sudo tee -a /home/fulcrum/.fulcrum/fulcrum.conf
else
  sudo sed -i "s/^#rpccookie/rpccookie/g" /home/fulcrum/.fulcrum/fulcrum.conf
fi
# make the .cookie file group readable
sudo chmod 640 /mnt/hdd/bitcoin/.cookie
# restart fulcrum
sudo systemctl restart fulcrum


## Electrs
# https://github.com/romanz/electrs/blob/master/doc/config_example.toml
# comment out auth="USER:PASSWORD" in the electrs.toml
sudo sed -i "s/^auth/#auth/g" /home/electrs/.electrs/config.toml
# add the elecrs user to the bitcoin group
sudo usermod -a -G bitcoin electrs
# symlink the cookie file to the electrs home dir
sudo -u electrs mkdir /home/electrs/.bitcoin
sudo ln -s /mnt/hdd/bitcoin/.cookie /home/electrs/.bitcoin/.cookie
# make the .cookie file group readable
sudo chmod 640 /mnt/hdd/bitcoin/.cookie
# restart electrs
sudo systemctl restart electrs

## Specter
# this process is to be simplified
# add the user to the bitcoin group
sudo usermod -a -G bitcoin specter
# symlink the cookie file to the home dir
sudo -u specter mkdir /home/specter/.bitcoin
sudo ln -s /mnt/hdd/bitcoin/.cookie /home/specter/.bitcoin/.cookie

# move /home/specter/.specter/config.json
sudo mv /home/specter/.specter/config.json /home/specter/.specter/config.json.bak
## move /home/specter/.specter/nodes/default.json
sudo mv /home/specter/.specter/nodes/default.json /home/specter/.specter/nodes/default.json.bak
# move /home/specter/.specter/nodes/raspiblitz_mainnet.json
sudo mv /home/specter/.specter/nodes/raspiblitz_mainnet.json /home/specter/.specter/nodes/raspiblitz_mainnet.json.bak

# make new specter config
proxy="socks5h://localhost:9050"
torOnly="true"
tor_control_port="9051"
chain="main"
cat > /home/admin/config.json <<EOF
{
    "auth": {
        "method": "none",
        "password_min_chars": 6,
        "rate_limit": 10,
        "registration_link_timeout": 1
    },
    "active_node_alias": "raspiblitz_${chain}net",
    "proxy_url": "${proxy}",
    "only_tor": "${torOnly}",
    "tor_control_port": "${tor_control_port}",
    "tor_status": true,
    "hwi_bridge_url": "/hwi/api/"
}
EOF
sudo mkdir -p /home/specter/.specter/nodes
sudo mv /home/admin/config.json /home/specter/.specter/config.json
sudo chown -RL specter:specter /home/specter/

sudo systemctl stop specter
# here I had an erro where needed to move the specter wallets folder
# not sure if this is reoccuring
sudo -u bitcoin cp -r /mnt/hdd/bitcoin/specter /mnt/hdd/bitcoin/specternewfolder

# restart specter
sudo systemctl restart specter

# open the Specter WebUI and set a password ASAP


#----------------

    echo
    echo "# Downloading and building ord $ordVERSION. This will take ~40 minutes"
    echo
    sudo -u ord git clone https://github.com/romanz/ord
    cd /home/ord/ord || exit 1

    sudo -u ord git reset --hard $ordVERSION

    # verify
    sudo -u ord /home/admin/config.scripts/blitz.git-verify.sh \
     "${PGPsigner}" "${PGPpubkeyLink}" "${PGPpubkeyFingerprint}" || exit 1

    # build
    sudo -u ord /home/ord/.cargo/bin/cargo build --release || exit 1

    echo
    echo "# The ord database will be built in /mnt/hdd/app-storage/ord/db. Takes ~18 hours and ~50Gb diskspace"
    echo
    sudo mkdir /mnt/hdd/app-storage/ord 2>/dev/null
    sudo chown -R ord:ord /mnt/hdd/app-storage/ord

    echo
    echo "# Getting RPC credentials from the bitcoin.conf"
    # read PASSWORD_B
    RPC_USER=$(sudo cat /mnt/hdd/bitcoin/bitcoin.conf | grep rpcuser | cut -c 9-)
    PASSWORD_B=$(sudo cat /mnt/hdd/bitcoin/bitcoin.conf | grep rpcpassword | cut -c 13-)
    echo "# Done"

    echo
    echo "# Generating ord.toml setting file with the RPC passwords"
    echo
    # generate setting file: https://github.com/romanz/ord/issues/170#issuecomment-530080134
    # https://github.com/romanz/ord/blob/master/doc/usage.md#configuration-files-and-environment-variables
    sudo -u ord mkdir /home/ord/.ord 2>/dev/null
    echo "\
log_filters = \"INFO\"
timestamp = true
jsonrpc_import = true
index-batch-size = 10
wait_duration_secs = 10
jsonrpc_timeout_secs = 15
db_dir = \"/mnt/hdd/app-storage/ord/db\"
auth = \"${RPC_USER}:${PASSWORD_B}\"
# allow BTC-RPC-explorer show tx-s for addresses with a history of more than 100
txid_limit = 1000
server_banner = \"Welcome to ord $ordVERSION - the Electrum Rust Server on your RaspiBlitz\"
" | sudo tee /home/ord/.ord/config.toml
    sudo chmod 600 /home/ord/.ord/config.toml
    sudo chown ord:ord /home/ord/.ord/config.toml

    echo
    echo "# Checking for config.toml"
    echo
    if [ ! -f "/home/ord/.ord/config.toml" ]
        then
            echo "Failed to create config.toml"
            exit 1
        else
            echo "OK"
    fi

    echo
    echo "# Setting up the nginx.conf"
    echo
    isord=$(sudo cat /etc/nginx/nginx.conf 2>/dev/null | grep -c 'upstream ord')
    if [ ${isord} -gt 0 ]; then
            echo "ord is already configured with Nginx. To edit manually run \`sudo nano /etc/nginx/nginx.conf\`"

    elif [ ${isord} -eq 0 ]; then

            isStream=$(sudo cat /etc/nginx/nginx.conf 2>/dev/null | grep -c 'stream {')
            if [ ${isStream} -eq 0 ]; then

            echo "
stream {
        upstream ord {
                server 127.0.0.1:50001;
        }
        server {
                listen 50002 ssl;
                proxy_pass ord;
                ssl_certificate /mnt/hdd/app-data/nginx/tls.cert;
                ssl_certificate_key /mnt/hdd/app-data/nginx/tls.key;
                ssl_session_cache shared:SSL-ord:1m;
                ssl_session_timeout 4h;
                ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
                ssl_prefer_server_ciphers on;
        }
}" | sudo tee -a /etc/nginx/nginx.conf

            elif [ ${isStream} -eq 1 ]; then
                    sudo truncate -s-2 /etc/nginx/nginx.conf
                    echo "
        upstream ord {
                server 127.0.0.1:50001;
        }
        server {
                listen 50002 ssl;
                proxy_pass ord;
                ssl_certificate /mnt/hdd/app-data/nginx/tls.cert;
                ssl_certificate_key /mnt/hdd/app-data/nginx/tls.key;
                ssl_session_cache shared:SSL-ord:1m;
                ssl_session_timeout 4h;
                ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
                ssl_prefer_server_ciphers on;
        }
}" | sudo tee -a /etc/nginx/nginx.conf

            elif [ ${isStream} -gt 1 ]; then
                    echo " Too many \`stream\` commands in nginx.conf. Please edit manually: \`sudo nano /etc/nginx/nginx.conf\` and retry"
                    exit 1
            fi
    fi


Benchmark          Min,   Avg,    Max
ecdsa_verify,      274.0, 285.0, 305.0
ecdsa_sign,        154.0, 162.0, 176.0
ecdh,              268.0, 282.0, 313.0
schnorrsig_sign,   134.0, 139.0, 149.0
schnorrsig_verify, 274.0, 287.0, 311.0


Benchmark, Min(us), Avg(us), Max(us)
ecdsa_verify, 53.9, 56.1, 59.3
ecdsa_sign, 40.0, 43.5, 61.0
ecdh, 55.2, 60.5, 79.4
schnorrsig_sign, 31.1, 32.3, 33.5
schnorrsig_verify, 55.8, 58.1, 59.9

    echo
    echo "# Open ports 50001 and 5002 on UFW "
    echo
    sudo ufw allow 50001 comment 'ord TCP'
    sudo ufw allow 50002 comment 'ord SSL'

    echo
    echo "# Installing the systemd service"
    echo
    # sudo nano /etc/systemd/system/ord.service
    echo "
[Unit]
Description=ord
After=bitcoind.service

[Service]
WorkingDirectory=/home/ord/ord
ExecStart=/home/ord/ord/target/release/ord --electrum-rpc-addr=\"0.0.0.0:50001\"
User=ord
Group=ord
Type=simple
TimeoutSec=60
Restart=always
RestartSec=60
LogLevelMax=5

# Hardening measures
PrivateTmp=true
ProtectSystem=full
NoNewPrivileges=true
PrivateDevices=true

[Install]
WantedBy=multi-user.target
    " | sudo tee -a /etc/systemd/system/ord.service
    sudo systemctl enable ord
    # manual start:
    # sudo -u ord /home/ord/.cargo/bin/cargo run --release -- --index-batch-size=10 --electrum-rpc-addr="0.0.0.0:50001"
  else
    echo "# ord is already installed."
  fi

  # setting value in raspiblitz config
  /home/admin/config.scripts/blitz.conf.sh set ord "on"

  # Hidden Service for ord if Tor active
  if [ "${runBehindTor}" = "on" ]; then
    # make sure to keep in sync with tor.network.sh script
    /home/admin/config.scripts/tor.onion-service.sh ord 50002 50002 50001 50001
  fi

  # whitelist downloading to localhost from bitcoind
  if ! sudo grep -Eq "^whitelist=download@127.0.0.1" /mnt/hdd/bitcoin/bitcoin.conf;then
    echo "whitelist=download@127.0.0.1" | sudo tee -a /mnt/hdd/bitcoin/bitcoin.conf
    bitcoindRestart=yes
  fi

  # clean up
  sudo rm -R /home/ord/.cargo
  sudo rm -R /home/ord/.rustup

  source <(/home/admin/_cache.sh get state)
  if [ "${state}" == "ready" ]; then
    if [ "${bitcoindRestart}" == "yes" ]; then
      sudo systemctl restart bitcoind
    fi
    sudo systemctl restart nginx
    sudo systemctl start ord
    # restart BTC-RPC-Explorer to reconfigure itself to use ord for address API
    if [ "${BTCRPCexplorer}" == "on" ]; then
      sudo systemctl restart btc-rpc-explorer
      echo "# BTC-RPC-Explorer restarted"
    fi
  fi

  echo
  echo "# To connect through SSL from outside of the local network make sure the port 50002 is forwarded on the router"
  echo

  exit 0
fi

# switch off
if [ "$1" = "0" ] || [ "$1" = "off" ]; then

  echo "# REMOVING ord"

  # if second parameter is "deleteindex"
  if [ "$2" == "deleteindex" ]; then
    echo "# deleting electrum index"
    sudo rm -rf /mnt/hdd/app-storage/ord/
  fi

  isInstalled=$(sudo ls /etc/systemd/system/ord.service 2>/dev/null | grep -c 'ord.service')
  if [ ${isInstalled} -eq 1 ]; then
    sudo systemctl disable ord
    sudo rm /etc/systemd/system/ord.service

    # restart BTC-RPC-Explorer to reconfigure itself to use ord for address API
    if [ "${BTCRPCexplorer}" == "on" ]; then
      sudo systemctl restart btc-rpc-explorer
      echo "# BTC-RPC-Explorer restarted"
    fi

  else
    echo "# ord.service is not installed."
  fi

  # Hidden Service if Tor is active
  if [ "${runBehindTor}" = "on" ]; then
    /home/admin/config.scripts/tor.onion-service.sh off ord
  fi

  # close ports on firewall
  sudo ufw delete allow 50001
  sudo ufw delete allow 50002

  # delete user and home directory
  sudo userdel -rf ord

  # setting value in raspiblitz config
  /home/admin/config.scripts/blitz.conf.sh set ord "off"

  echo "# OK ord removed."
  exit 0
fi

if [ "$1" = "update" ]; then
  echo "# Update ord"
  cd /home/ord/ord || exit 1
  sudo -u ord git fetch

  localVersion=$(/home/ord/ord/target/release/ord --version)
  updateVersion=$(curl --header "X-GitHub-Api-Version:2022-11-28" -s https://api.github.com/repos/romanz/ord/releases/latest|grep tag_name|head -1|cut -d '"' -f4)

  if [ $localVersion = $updateVersion ]; then
    echo "# Up-to-date on version $localVersion"
  else
    echo "# Pulling latest changes..."
    sudo -u ord git pull -p
    echo "# Reset to the latest release tag: $updateVersion"
    sudo -u ord git reset --hard $updateVersion

    sudo -u ord /home/admin/config.scripts/blitz.git-verify.sh \
     "${PGPsigner}" "${PGPpubkeyLink}" "${PGPpubkeyFingerprint}" || exit 1

    echo "# Installing build dependencies"
    sudo -u ord curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sudo -u ord sh -s -- --default-toolchain none -y
    sudo apt install -y clang cmake build-essential  # for building 'rust-rocksdb'
    echo

    echo "# Build ord ..."
    sudo -u ord /home/ord/.cargo/bin/cargo build --locked --release || exit 1

    # update config
    sudo -u ord sed -i "/^server_banner = /d" /home/ord/.ord/config.toml
    sudo -u ord bash -c "echo 'server_banner = \"Welcome to ord $updateVersion - the Electrum Rust Server on your RaspiBlitz\"' >> /home/ord/.ord/config.toml"

    echo "# Updated ord to $updateVersion"
  fi
  sudo systemctl start ord
  exit 0
fi

echo "# FAIL - Unknown Parameter $1"
exit 1
