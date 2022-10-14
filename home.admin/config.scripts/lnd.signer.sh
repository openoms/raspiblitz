#!/bin/bash

# https://github.com/lightningnetwork/lnd/releases/
LNDVERSION="v0.15.2-beta"

# help
if [ $# -eq 0 ]||[ "$1" = "-h" ]||[ "$1" = "--help" ];then
  echo
  echo "script to install a LND"
  echo "Do not connect more than 3 instances to a bitcoin node!"
  echo "the default version is: $LNDVERSION"
  echo "the nodenumber defaults to '1'"
  echo "Usage:"
  echo "install.lnd.sh [on <nodenumber>|off <nodenumber> <purge>] <mainnet|testnet|signett>"
  echo
  echo "to add the node to BoS, ThunderHub, Sphinx or export macaroons & tls.cert:"
  echo "install.lnd.sh menu"
  echo "install.lnd.sh [bos|sphinx|thunderhub|hexstring|scp|http|btcpay <nodenumber>]"
  echo
  echo "install.lnd.sh [selftest|torinstance]"
  echo
  exit 1
fi

# vars

source <(/home/admin/_cache.sh get network)
if [ "${network}" == "" ]; then
  network="bitcoin"
fi


if [ -f /home/joinmarket/joinin.conf ];then
  source /home/joinmarket/joinin.conf
  CHAIN=$network
fi
if [ -f /mnt/hdd/raspiblitz.conf ];then
  source /mnt/hdd/raspiblitz.conf
  runningEnv="raspiblitz"
  CHAIN=${chain}net
fi

source <(/home/admin/config.scripts/network.aliases.sh getvars lnd $3)

LNDUSER="bitcoin"
if [ ${#2} -eq 0 ]||[ $2 = purge ];then
  NODENUMBER=1
else
  NODENUMBER="$2"
fi
if [ ${#NODENUMBER} -eq 0 ]||[ ${NODENUMBER} = "" ];then
  echo "# Must use a node number"
  exit 1
fi
if [ $runningEnv = raspiblitz ];then
  APPDATADIR="/mnt/hdd/app-data"
elif [ $runningEnv = standalone ];then
  addUserStore
  APPDATADIR="/home/store/app-data"
fi
if [ $runningEnv = standalone ];then
  BITCOINDIR="/home/${LNDUSER}/bitcoin"
  BTCCONFPATH="/home/${LNDUSER}/.bitcoin/bitcoin.conf"
elif [ $runningEnv = raspiblitz ];then
  BITCOINDIR="/usr/local/bin"
  BTCCONFPATH="/home/bitcoin/.bitcoin/bitcoin.conf"
fi

echo
echo "NODENUMBER=$NODENUMBER"
echo "CHAIN=$CHAIN"
echo "LNDUSER=$LNDUSER"
echo "APPDATADIR=$APPDATADIR"
echo
echo "# Running the command: 'install.lnd.sh $*'"

if [ "$1" = on ]||[ "$1" = update ]||[ "$1" = commit ]||[ "$1" = testPR ];then
  echo "# Press ENTER to continue or CTRL+C to exit"
  read key

  if [ ! -f /usr/local/bin/lnd ]||[ "$1" = update ]||[ "$1" = commit ]||[ "$1" = testPR ];then
    rm -rf lnd.update.${LNDVERSION}.sh
    # download
    wget https://raw.githubusercontent.com/openoms/lightning-node-management/master/lnd.updates/lnd.update.${LNDVERSION}.sh
    # look through the script
    cat lnd.update.${LNDVERSION}.sh || exit 1
    # run
    chmod +x lnd.update.${LNDVERSION}.sh || exit 1
    ./lnd.update.${LNDVERSION}.sh || exit 1
  fi

  # config
  echo "# Store the lightning data in $APPDATADIR/.lnd${NODENUMBER}"
  echo "# Symlink to /home/${LNDUSER}/"
  # not a symlink, delete
  sudo rm -rf /home/${LNDUSER}/.lnd${NODENUMBER}
  sudo mkdir -p $APPDATADIR/.lnd${NODENUMBER}
  sudo ln -s $APPDATADIR/.lnd${NODENUMBER} /home/${LNDUSER}/
  echo "# Create /home/${LNDUSER}/.lnd${NODENUMBER}/config"
  if [ ! -f /home/${LNDUSER}/.lnd${NODENUMBER}/config ];then
    echo "
# ${netprefix}lnd${NODENUMBER} configuration for $CHAIN
# We apply some basic "hardening" parameters to make sure no connections to the
# internet are opened.

[Application Options]
# Don't listen on the p2p port.
nolisten=true

# Don't reach out to the bootstrap nodes, we don't need a synced graph.
nobootstrap=true

# Just an example, this is the port that needs to be opened in the firewall and
# reachable from the node "watch-only".
rpclisten=1${rpcportmod}0${NODENUMBER}9

restlisten=0.0.0.0:${portprefix}8808${NODENUMBER}

# The signer node will not look at the chain at all, it only needs to sign
# things with the keys contained in its wallet. So we don't need to hook it up
# to any chain backend.
[bitcoin]
# We still need to signal that we're using the Bitcoin chain.
bitcoin.active=true

# And we're making sure mainnet parameters are used.
bitcoin.${CHAIN}=true

# But we aren't using a "real" chain backed but a mocked one.
bitcoin.node=nochainbackend
" | sudo tee /home/${LNDUSER}/.lnd${NODENUMBER}/${netprefix}lnd.conf
  else
    echo "# The file /home/${LNDUSER}/.lnd${NODENUMBER}/${netprefix}lnd.conf is already present"
  fi
  sudo chown -R ${LNDUSER}:${LNDUSER} $APPDATADIR/.lnd${NODENUMBER}
  sudo chown -R ${LNDUSER}:${LNDUSER} /home/${LNDUSER}/

  # systemd service
  sudo systemctl stop ${netprefix}lnd${NODENUMBER}
  echo "# Create /etc/systemd/system/${netprefix}lnd${NODENUMBER}.service"
  echo "
[Unit]
Description=LND${NODENUMBER} on $CHAIN

[Service]
User=${LNDUSER}
Group=${LNDUSER}
Type=simple
ExecStart=/usr/local/bin/lnd \
  --lnddir=\"/home/${LNDUSER}/.lnd${NODENUMBER}/\" \
  --bitcoin.$CHAIN
Restart=always
TimeoutSec=120
RestartSec=30
StandardOutput=null
StandardError=journal

[Install]
WantedBy=multi-user.target
" | sudo tee /etc/systemd/system/${netprefix}lnd${NODENUMBER}.service
  sudo systemctl daemon-reload
  sudo systemctl enable ${netprefix}lnd${NODENUMBER}
  sudo systemctl start ${netprefix}lnd${NODENUMBER}
  echo "# OK - the ${netprefix}lnd${NODENUMBER}.service is now enabled and started"
  echo
  echo "# Adding aliases for $runningEnv"
  if [ $runningEnv = standalone ];then
    if [ $(grep -c "sudo -u ${LNDUSER} $BITCOINDIR/bitcoin-cli" < /home/joinmarket/_aliases ) -eq 0 ];then
        echo "
alias bitcoin-cli=\"sudo -u ${LNDUSER} $BITCOINDIR/bitcoin-cli\"
alias bcli=\"sudo -u ${LNDUSER} $BITCOINDIR/bitcoin-cli -network=$CHAIN\"\
" | sudo tee -a /home/joinmarket/_aliases
    fi
    ALIASFILE="/home/joinmarket/_aliases"
  elif [ $runningEnv = raspiblitz ];then
    ALIASFILE="/home/admin/_aliases"
  fi
  echo "
alias ${netprefix}lncli${NODENUMBER}=\"sudo -u ${LNDUSER} /usr/local/bin/lncli\
 --lnddir=\"/home/${LNDUSER}/.lnd${NODENUMBER}/\"\
 --network=$CHAIN\
 --rpcserver localhost:1${rpcportmod}0${NODENUMBER}9\"" | sudo tee -a $ALIASFILE

  echo "# To activate the aliases reopen the terminal or use 'source $ALIASFILE'"
  echo
  echo "# The installed LND version is: $(sudo -u ${LNDUSER} /usr/local/bin/lnd --version)"
  echo
  echo "# Monitor the ${netprefix}lnd${NODENUMBER} with:"
  echo "# 'sudo journalctl -fu ${netprefix}lnd${NODENUMBER}'"
  echo "# 'sudo systemctl status ${netprefix}lnd${NODENUMBER}'"
  echo "# logs: 'sudo tail -f /home/bitcoin/.lnd1/logs/bitcoin/$CHAIN/lnd.log'"
  echo "# Use: '${netprefix}lncli${NODENUMBER} help' for the command line options"
  echo
fi

if [ "$1" = "off" ];then
  echo "# Removing the ${netprefix}lnd${NODENUMBER}.service"
  sudo systemctl disable ${netprefix}lnd${NODENUMBER}
  sudo systemctl stop ${netprefix}lnd${NODENUMBER}
  echo "# Removing the aliases"
  if [ $runningEnv = standalone ];then
    ALIASFILE="/home/joinmarket/_aliases"
  elif [ $runningEnv = raspiblitz ];then
    ALIASFILE="/home/admin/_aliases"
  fi
  sudo sed -i "/${netprefix}lncli${NODENUMBER}/d" $ALIASFILE

  if [ "$(echo "$@" | grep -c purge)" -gt 0 ];then
    echo "# Removing the binaries"
    sudo rm -f /usr/local/bin/lnd
    sudo rm -f /usr/local/bin/lncli
  fi
fi

########
# MENU #
########
if [ "$1" =  menu ]||[ "$1" =  hexstring ]||[ "$1" =  scp ]||\
   [ "$1" =  http ]||[ "$1" =  btcpay ]||[ "$1" =  bos ]||\
   [ "$1" =  thunderhub ]||[ "$1" =  sphinx ]||[ "$1" =  selftest ]||\
   [ "$1" =  torinstance ];then
  # 1. parameter -> the type of export
  exportType=$1
  # interactive choose type of export if not set
  if [ "$1" = "menu" ]; then
      OPTIONS=()
      OPTIONS+=(SCP "SSH Download (Commands)")
      OPTIONS+=(HTTP "Browserdownload (bit risky)")
      OPTIONS+=(HEX "Hex-String (Copy+Paste)")
      OPTIONS+=(STR "BTCPay Connection String")

      CHOICE=$(dialog \
                  --backtitle "RaspiBlitz" \
                  --title "Export Macaroons & TLS.cert" \
                  --menu "How do you want to export?" \
                  16 52 10 \
                  "${OPTIONS[@]}" \
                  2>&1 >/dev/tty)
      clear
      case $CHOICE in
        HEX)
          exportType='hexstring';;
        STR)
          exportType='btcpay';;
        SCP)
          exportType='scp';;
        HTTP)
          exportType='http';;
      esac
  fi
  # load data from config
  source /home/admin/raspiblitz.info
  source /mnt/hdd/raspiblitz.conf
  # CANCEL
  if [ ${#exportType} -eq 0 ]; then
    echo "CANCEL"
    exit 0

  ########################
  # HEXSTRING
  ########################
  elif [ "${exportType}" = "hexstring" ]; then
    clear
    echo "###### HEXSTRING EXPORT ######"
    echo ""
    echo "admin.macaroon:"
    sudo xxd -ps -u -c 1000 /home/bitcoin/.lnd${NODENUMBER}/data/chain/${network}/${chain}net/admin.macaroon
    echo ""
    echo "invoice.macaroon:"
    sudo xxd -ps -u -c 1000 /home/bitcoin/.lnd${NODENUMBER}/data/chain/${network}/${chain}net/invoice.macaroon
    echo ""
    echo "readonly.macaroon:"
    sudo xxd -ps -u -c 1000 /home/bitcoin/.lnd${NODENUMBER}/data/chain/${network}/${chain}net/readonly.macaroon
    echo ""
    echo "tls.cert:"
    sudo xxd -ps -u -c 1000 /home/bitcoin/.lnd${NODENUMBER}/tls.cert
    echo

  ###########################
  # SHH / SCP File Download
  ###########################
  elif [ "${exportType}" = "scp" ]; then
    local_ip=$(ip addr | grep 'state UP' -A2 | egrep -v 'docker0|veth' | grep 'eth0\|wlan0' | tail -n1 | awk '{print $2}' | cut -f1 -d'/')
    clear
    echo "###### DOWNLOAD BY SCP ######"
    echo "Copy, paste and execute these commands in your client terminal to download the files."
    echo "The password needed during download is your Password A."
    echo ""
    echo "Macaroons:"
    echo "scp bitcoin@${local_ip}:/home/bitcoin/.lnd${NODENUMBER}/data/chain/${network}/${chain}net/\*.macaroon ./"
    echo ""
    echo "TLS Certificate:"
    echo "scp bitcoin@${local_ip}:/home/bitcoin/.lnd${NODENUMBER}/tls.cert ./"
    echo ""

  ###########################
  # HTTP File Download
  ###########################
  elif [ "${exportType}" = "http" ]; then
    local_ip=$(ip addr | grep 'state UP' -A2 | egrep -v 'docker0|veth' | grep 'eth0\|wlan0' | tail -n1 | awk '{print $2}' | cut -f1 -d'/')
    randomPortNumber=$(shuf -i 20000-39999 -n 1)
    sudo ufw allow from 192.168.0.0/16 to any port ${randomPortNumber} comment 'temp http server'
    clear
    echo "###### DOWNLOAD BY HTTP ######"
    echo ""
    echo "Open in your browser --> http://${local_ip}:${randomPortNumber}"
    echo ""
    echo "You need to be on the same local network - not reachable from outside."
    echo "In browser click on files or use 'save as' from context menu to download."
    echo ""
    echo "Temp HTTP Server is running - use CTRL+C to stop when you are done"
    echo ""
    cd
    randomFolderName=$(shuf -i 100000000-900000000 -n 1)
    mkdir ${randomFolderName}
    sudo cp /home/bitcoin/.lnd${NODENUMBER}/data/chain/${network}/${chain}net/admin.macaroon ./${randomFolderName}/admin.macaroon
    sudo cp /home/bitcoin/.lnd${NODENUMBER}/data/chain/${network}/${chain}net/readonly.macaroon ./${randomFolderName}/readonly.macaroon
    sudo cp /home/bitcoin/.lnd${NODENUMBER}/data/chain/${network}/${chain}net/invoice.macaroon ./${randomFolderName}/invoice.macaroon
    sudo cp /home/bitcoin/.lnd${NODENUMBER}/tls.cert ./${randomFolderName}/tls.cert
    cd ${randomFolderName}
    sudo chmod 444 *.*
    python3 -m http.server ${randomPortNumber} 2>/dev/null
    sudo ufw delete allow from 192.168.0.0/16 to any port ${randomPortNumber} comment 'temp http server'
    cd ..
    sudo rm -r ${randomFolderName}
    echo "OK - temp HTTP server is stopped."
  fi
fi
