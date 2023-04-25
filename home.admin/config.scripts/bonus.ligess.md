#!/bin/bash

#https://github.com/Dolu89/ligess


sudo adduser --disabled-password --gecos "" ligess
cd /home/ligess || exit 1

/home/admin/config.scripts/bonus.nodejs.sh on
source <(/home/admin/config.scripts/bonus.nodejs.sh info)
if ! sudo npm install --global yarn; then
  echo "error='install yarn failed'"
  exit 1
fi
${NODEPATH}/yarn config set --home enableTelemetry 0

sudo -u ligess git clone https://github.com/dolu89/ligess
cd ligess
if ! sudo -u ligess ${NODEPATH}/yarn install; then
  echo "error='yarn install failed'"
  exit 1
fi

sudo -u ligess cp .env.example .env

# Edit .env with your info
sudo nano /home/ligess/ligess/.env
```
# choose a username
LIGESS_USERNAME=ligess
# use the onion address here
LIGESS_DOMAIN=diynodes.com
# choose a port
PORT=3100
# don't use tor on the same machine as the node
LIGESS_TOR_PROXY_URL=socks5h://127.0.0.1:9050
LIGESS_LN_BACKEND=LND
LIGESS_LND_REST=https://<onion link from CONNECT - MOBILE - ZEUS - CONSOLE QRcode>:8080
LIGESS_LND_MACAROON=<hex invoice macaroon from CONNECT menu>
LIGESS_NOSTR_ZAPPER_PRIVATE_KEY=<use a new nostr hesx key from iris.to and save it>
```

source <(/home/admin/config.scripts/bonus.nodejs.sh info)
sudo -u ligess ${NODEPATH}/yarn dev



Nginx config:
```                                                                                                                                                                                                                                                                                                                                                                                                     /etc/nginx/sites-enabled/diynodes.com

Set up SSL for a (sub)domain:

Once you have SSL set up for a d

location /.well-known/nostr.json {
  add_header 'Access-Control-Allow-Origin' '*';
  alias /var/www/html/.well-known/nostr.json;
}


location /.well-known/lnurlp/ligess {
  add_header 'Access-Control-Allow-Origin' '*';

  proxy_pass      http://127.0.0.1:3100;
  proxy_redirect off;

  proxy_set_header Host $http_host;
  proxy_set_header X-Real-IP $remote_addr;
  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto https;

  proxy_read_timeout 600;
  proxy_connect_timeout 600;
  proxy_send_timeout 600;
  }
}

```














