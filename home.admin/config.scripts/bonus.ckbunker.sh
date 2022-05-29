#!/bin/bash

# https://github.com/lightninglabs/ckbunker/releases-
pinnedVersion="bf08623875b576c4bc4498dc68e749cdf6b5de31"

# command info
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "-help" ]; then
  echo "# Config script to switch the CKbunker on or off"
  echo "# bonus.ckbunker.sh [on|off|menu|setup|run]"
  echo "# Installs CKBunker $pinnedVersion"
  echo "# bonus.${APPID}.sh status   -> status information (key=value)"
  echo "# bonus.${APPID}.sh on       -> install the app"
  echo "# bonus.${APPID}.sh off      -> uninstall the app"
  echo "# bonus.${APPID}.sh menu     -> SSH menu dialog"
  echo "# bonus.${APPID}.sh prestart -> will be called by systemd before start"
  exit 1
fi

source /mnt/hdd/raspiblitz.conf

APPID="ckbunker"
GITHUB_SIGN_AUTHOR="web-flow"
GITHUB_SIGN_PUBKEYLINK="https://github.com/web-flow.gpg"
GITHUB_SIGN_FINGERPRINT="4AEE18F83AFDEB23"

PORT_CLEAR="9823"
PORT_SSL="9824"
PORT_TOR_CLEAR="9825"
PORT_TOR_SSL="9826"


# check if app is already installed
isInstalled=$(sudo ls /etc/systemd/system/${APPID}.service 2>/dev/null | grep -c "${APPID}.service")

# check if service is running
isRunning=$(systemctl status ${APPID} 2>/dev/null | grep -c 'active (running)')

if [ "${isInstalled}" == "1" ]; then

  # gather address info (whats needed to call the app)
  localIP=$(hostname -I | awk '{print $1}')
  toraddress=$(sudo cat /mnt/hdd/tor/${APPID}/hostname 2>/dev/null)
  fingerprint=$(openssl x509 -in /mnt/hdd/app-data/nginx/tls.cert -fingerprint -noout | cut -d"=" -f2)

fi

if [ "$1" = "status" ]; then
  echo "appID='${APPID}'"
  echo "githubRepo='${GITHUB_REPO}'"
  echo "githubVersion='${GITHUB_VERSION}'"
  echo "githubSignature='${GITHUB_SIGNATURE}'"
  echo "isInstalled=${isInstalled}"
  echo "isRunning=${isRunning}"
  if [ "${isInstalled}" == "1" ]; then
    echo "portCLEAR=${PORT_CLEAR}"
    echo "portSSL=${PORT_SSL}"
    echo "localIP='${localIP}'"
    echo "toraddress='${toraddress}'"
    echo "fingerprint='${fingerprint}'"
    echo "toraddress='${toraddress}'"
  fi
  exit
fi

# show info menu
if [ "$1" = "menu" ]; then
  # basic info text - for an web app how to call with http & self-signed https
  dialogText="Open in your local web browser:
http://${localIP}:${PORT_CLEAR}\n
https://${localIP}:${PORT_SSL} with Fingerprint:
${fingerprint}\n
Use your Password B to login.\n
"

  # add tor info (if available)
  if [ "${toraddress}" != "" ]; then
    dialogText="${dialogText}Hidden Service address for Tor Browser (QRcode on LCD):\n${toraddress}"
  fi
  dialogText="${dialogText}
Usage and examples: https://github.com/Coldcard/ckbunker
For the CLI: use the shortcut 'ckbunker' in the terminal to switch to the dedicated user.
Type 'ckbunker' again to see the available options."

  # use whiptail to show SSH dialog & exit
  whiptail --title "${dialogTitle}" --msgbox "${dialogText}" 18 67
  echo "please wait ..."
  exit 0
fi

# switch on
if [ "$1" = "1" ] || [ "$1" = "on" ]; then
  echo "# Install CKBunker"

  if [ ${isInstalled} -eq 1 ]; then
    echo "# ${APPID}.service is already installed."
    exit 1
  fi

  echo "# Installing ${APPID} ..."

  # dependencies
  sudo apt install -y virtualenv python-dev libusb-1.0-0-dev libudev-dev

  # create dedicated user
  sudo adduser --disabled-password --gecos "" ckbunker

  # add the user to the Tor group
  sudo usermod -a -G debian-tor ckbunker

  if ! [ -d /mnt/hdd/app-data/${APPID} ]; then
    echo "# create app-data directory"
    sudo mkdir /mnt/hdd/app-data/${APPID} 2>/dev/null
    sudo chown ${APPID}:${APPID} -R /mnt/hdd/app-data/${APPID}
  else
    echo "# reuse existing app-directory"
    sudo chown ${APPID}:${APPID} -R /mnt/hdd/app-data/${APPID}
  fi

  echo "# download the source code & verify"
  sudo -u ${APPID} git clone --recursive ${GITHUB_REPO} /home/${APPID}/${APPID}
  cd /home/${APPID}/${APPID}
  sudo -u ${APPID} git reset --hard $GITHUB_VERSION
  if [ "${GITHUB_SIGN_AUTHOR}" != "" ]; then
    sudo -u ${APPID} /home/admin/config.scripts/blitz.git-verify.sh \
     "${GITHUB_SIGN_AUTHOR}" "${GITHUB_SIGN_PUBKEYLINK}" "${GITHUB_SIGN_FINGERPRINT}" "${GITHUB_VERSION}" || exit 1
  fi

  cd ckbunker
  sudo -u ckbunker  virtualenv -p python3 ENV
  source ENV/bin/activate
  sudo -u ckbunker pip install -r requirements.txt
  sudo -u ckbunker pip install --editable .

  echo "# add the udev rules"
  cd /etc/udev/rules.d/
  sudo wget https://raw.githubusercontent.com/Coldcard/ckcc-protocol/master/51-coinkite.rules
  sudo udevadm control --reload-rules && sudo udevadm trigger

  echo "# updating Firewall"
  sudo ufw allow ${PORT_CLEAR} comment "${APPID} HTTP"
  sudo ufw allow ${PORT_SSL} comment "${APPID} HTTPS"

  echo "# create systemd service: ${APPID}.service"
  echo "
[Unit]
Description=${APPID}
Wants=bitcoind
After=bitcoind

[Service]
Environment=\"HOME_PATH=/mnt/hdd/app-data/${APPID}\"
ExecStartPre=-/home/admin/config.scripts/bonus.${APPID}.sh prestart
ExecStart=/usr/bin/node /home/${APPID}/${APPID}/${APPID}
User=${APPID}
Restart=always
TimeoutSec=120
RestartSec=30
StandardOutput=null
StandardError=journal

# Hardening measures
PrivateTmp=true
ProtectSystem=full
NoNewPrivileges=true
PrivateDevices=true

[Install]
WantedBy=multi-user.target
" | sudo tee /etc/systemd/system/${APPID}.service
    sudo chown root:root /etc/systemd/system/${APPID}.service

  # when tor is set on also install the hidden service
  if [ "${runBehindTor}" = "on" ]; then
    # activating tor hidden service
    /home/admin/config.scripts/tor.onion-service.sh ${APPID} 80 ${PORT_TOR_CLEAR} 443 ${PORT_TOR_SSL}
  fi

  echo "# setup nginx confing"
  # write the HTTPS config
  echo "
server {
    listen ${PORT_SSL} ssl;
    listen [::]:${PORT_SSL} ssl;
    server_name _;
    include /etc/nginx/snippets/ssl-params.conf;
    include /etc/nginx/snippets/ssl-certificate-app-data.conf;
    access_log /var/log/nginx/access_${APPID}.log;
    error_log /var/log/nginx/error_${APPID}.log;
    location / {
        proxy_pass http://127.0.0.1:${PORT_CLEAR};
        include /etc/nginx/snippets/ssl-proxy-params.conf;
    }
}
" | sudo tee /etc/nginx/sites-available/${APPID}_ssl.conf
  sudo ln -sf /etc/nginx/sites-available/${APPID}_ssl.conf /etc/nginx/sites-enabled/

  # write the Tor config
  echo "
server {
    listen localhost:${PORT_TOR_CLEAR};
    server_name _;
    access_log /var/log/nginx/access_${APPID}.log;
    error_log /var/log/nginx/error_${APPID}.log;
    location / {
        proxy_pass http://127.0.0.1:${PORT_CLEAR};
        include /etc/nginx/snippets/ssl-proxy-params.conf;
    }
}
" | sudo tee /etc/nginx/sites-available/${APPID}_tor.conf
  sudo ln -sf /etc/nginx/sites-available/${APPID}_tor.conf /etc/nginx/sites-enabled/

  # write the Tor+HTTPS config
  echo "
server {
    listen localhost:${PORT_TOR_SSL} ssl;
    server_name _;
    include /etc/nginx/snippets/ssl-params.conf;
    include /etc/nginx/snippets/ssl-certificate-app-data-tor.conf;
    access_log /var/log/nginx/access_${appID}.log;
    error_log /var/log/nginx/error_${appID}.log;
    location / {
        proxy_pass http://127.0.0.1:${PORT_CLEAR};
        include /etc/nginx/snippets/ssl-proxy-params.conf;
    }
}
" | sudo tee /etc/nginx/sites-available/${APPID}_tor_ssl.conf
  sudo ln -sf /etc/nginx/sites-available/${APPID}_tor_ssl.conf /etc/nginx/sites-enabled/

  # test nginx config & activate thru reload
  sudo nginx -t
  sudo systemctl reload nginx

  # mark app as installed in raspiblitz config
  /home/admin/config.scripts/blitz.conf.sh set ${APPID} "on"

  sudo systemctl enable ${APPID}
  sudo systemctl start ${APPID}
  echo "# OK - the ${APPID}.service is now enabled & started"
  echo "# Monitor with: sudo journalctl -f -u ${APPID}"
  exit 0
fi


# switch off
if [ "$1" = "0" ] || [ "$1" = "off" ]; then

  echo "# stop & remove systemd service"
  sudo systemctl stop ${APPID} 2>/dev/null
  sudo systemctl disable ${APPID}.service
  sudo rm /etc/systemd/system/${APPID}.service

  echo "# remove nginx symlinks"
  sudo rm -f /etc/nginx/sites-enabled/${APPID}_ssl.conf 2>/dev/null
  sudo rm -f /etc/nginx/sites-enabled/${APPID}_tor.conf 2>/dev/null
  sudo rm -f /etc/nginx/sites-enabled/${APPID}_tor_ssl.conf 2>/dev/null
  sudo rm -f /etc/nginx/sites-available/${APPID}_ssl.conf 2>/dev/null
  sudo rm -f /etc/nginx/sites-available/${APPID}_tor.conf 2>/dev/null
  sudo rm -f /etc/nginx/sites-available/${APPID}_tor_ssl.conf 2>/dev/null
  sudo nginx -t
  sudo systemctl reload nginx

  echo "# close ports on firewall"
  sudo ufw deny "${PORT_CLEAR}"
  sudo ufw deny "${PORT_SSL}"

  echo "# removing Tor hidden service (if active)"
  /home/admin/config.scripts/tor.onion-service.sh off ${APPID}

  echo "# mark app as uninstalled in raspiblitz config"
  /home/admin/config.scripts/blitz.conf.sh set ${APPID} "off"

  # only if 'delete-data' is an additional parameter then also the data directory gets deleted
  if [ "$(echo "$@" | grep -c delete-data)" -gt 0 ]; then
    echo "# found 'delete-data' parameter --> also deleting the app-data"
    sudo rm -r /mnt/hdd/app-data/${APPID}
  fi

  echo "# OK - app should be uninstalled now"
  exit 0
fi

# just a basic error message when unknow action parameter was given
echo "# FAIL - Unknown Parameter $1"
exit 1
