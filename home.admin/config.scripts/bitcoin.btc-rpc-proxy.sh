## INSTALLL
# https://github.com/casey/btcproxy#installation

# system dependencies
sudo apt-get install libssl-dev gcc

# create user
sudo adduser --disabled-password --gecos "" btcproxy
# switch to user
sudo su - btcproxy
# install rust for the user
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"
# download source
git clone https://github.com/Kixunil/btc-rpc-proxy
cd btc-rpc-proxy
# build
cargo build --release

# https://github.com/Kixunil/btc-rpc-proxy/blob/master/btc_rpc_proxy.toml
cat <<EOF > btc_rpc_proxy.toml
#bitcoind_user = "bitcoinrpc"
#bitcoind_password = "taxation is theft"
bind_address = "127.0.0.1"

[user.public]
password = "public"
allowed_calls = [
	"getinfo",
	"getblock",
	"getblockchaininfo",
	"getbestblockhash",
	"getblockcount",
	"getblockhash",
	"getblockheader",
	"getchaintips",
	"getdifficulty",
	"getnetworkinfo",
	"getmempoolinfo",
	"getrawmempool",
	"gettxout",
	"gettxoutproof",
	"gettxoutsetinfo",
	"verifytxoutproof",
	"createrawtransaction",
	"decoderawtransaction",
	"decodescript",
	"getrawtransaction",
	"sendrawtransaction",
	"estimatefee",
	"estimatepriority",
	"estimatesmartfee",
	"estimatesmartpriority"
]

[user.raspibolt]
password = "mempool"
allowed_calls = [
	"getinfo",
	"getblock",
	"getblockchaininfo",
	"getbestblockhash",
	"getblockcount",
	"getblockhash",
	"getblockheader",
	"getchaintips",
	"getdifficulty",
	"getnetworkinfo",
	"getmempoolinfo",
	"getrawmempool",
	"gettxout",
	"gettxoutproof",
	"gettxoutsetinfo",
	"verifytxoutproof",
	"createrawtransaction",
	"decoderawtransaction",
	"decodescript",
	"getrawtransaction",
	"sendrawtransaction",
	"estimatefee",
	"estimatepriority",
	"estimatesmartfee",
	"estimatesmartpriority"
]

EOF

# prepare bitcoind (apps realying on rpcuser and rpcpasswbtcproxy auth will stop working)
# comment out rpcuser and rpcpasswbtcproxy in bitcoin.conf
sudo sed -i "s/^rpcuser/#rpcuser/g" /mnt/hdd/bitcoin/bitcoin.conf
sudo sed -i "s/^rpcpasswbtcproxy/#rpcpasswbtcproxy/g" /mnt/hdd/bitcoin/bitcoin.conf
# restart bitcoind
sudo systemctl restart bitcoind
# make the .cookie file group readable
sudo chmod 640 /mnt/hdd/bitcoin/.cookie
# add the btcproxy user to the bitcoin group
sudo usermod -a -G bitcoin btcproxy
# symlink cookie file to home directory
sudo -u btcproxy mkdir /home/btcproxy/.bitcoin
sudo ln -s /mnt/hdd/bitcoin/.cookie /home/btcproxy/.bitcoin/.cookie


# run manually
#cargo run --release -- --conf btc_rpc_proxy.toml

# systemd service
cat <<EOF > /etc/systemd/system/btc-rpc-proxy.service
[Unit]
Description=BTC RPC Proxy
After=network.target

[Service]
User=btcproxy
Group=btcproxy
Type=simple
ExecStart=/home/btcproxy/btc-rpc-proxy/target/release/btc_rpc_proxy --conf /home/btcproxy/btc-rpc-proxy/btc_rpc_proxy.toml
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF


