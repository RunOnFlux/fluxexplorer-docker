#!/usr/bin/env bash
# install needed dependencies

if [[ ! -d /root/bitcore-node ]]; then
curl -sL https://deb.nodesource.com/setup_8.x | bash -
apt-get install -y nodejs
apt-get install -y build-essential
apt-get install -y libzmq3-dev
apt-get install -y npm git

#bitcore-node
cd /root/
bash flux-fetch-params.sh > /dev/null 2>&1 && sleep 2
git clone https://github.com/runonflux/bitcore-node
cd bitcore-node
npm install
cd bin
chmod +x bitcore-node
./bitcore-node create mynode
cd mynode
rm bitcore-node.json
cat << EOF > bitcore-node.json
{
  "network": "livenet",
  "port": 3001,
  "services": [
    "bitcoind",
    "insight-api",
    "insight-ui",
    "web"
  ],
  "messageLog": "",
  "servicesConfig": {
      "web": {
      "disablePolling": false,
      "enableSocketRPC": false
    },
    "bitcoind": {
      "sendTxLog": "./data/pushtx.log",
      "spawn": {
        "datadir": "./data",
        "exec": "fluxd",
        "rpcqueue": 1000,
        "rpcport": 16124,
        "zmqpubrawtx": "tcp://127.0.0.1:28332",
        "zmqpubhashblock": "tcp://127.0.0.1:28332"
      }
    },
    "insight-api": {
        "routePrefix": "api",
                 "db": {
                   "host": "fluxmongodb_explorerflux",
                   "port": "27017",
                   "database": "flux-api-livenet",
                   "user": "",
                   "password": ""
          },
          "disableRateLimiter": true
    },
    "insight-ui": {
        "apiPrefix": "api",
        "routePrefix": ""
    }
  }
}
EOF

cp /usr/local/bin/fluxd /root/bitcore-node/bin/fluxd
chmod +x /root/bitcore-node/bin/fluxd
cd data
cat << EOF > flux.conf
server=1
whitelist=127.0.0.1
txindex=1
addressindex=1
timestampindex=1
spentindex=1
insightexplorer=1
experimentalfeatures=1
zmqpubrawtx=tcp://127.0.0.1:28332
zmqpubhashblock=tcp://127.0.0.1:28332
rpcport=16124
rpcallowip=127.0.0.1
rpcuser=flux
rpcpassword=myfluxpassword
uacomment=bitcore
mempoolexpiry=24
rpcworkqueue=1100
maxmempool=2000
dbcache=1000
maxtxfee=1.0
dbmaxfilesize=64
showmetrics=0
addnode=explorer.flux.zelcore.io
addnode=explorer.runonflux.io
addnode=explorer.zelcash.online
addnode=blockbook.runonflux.io
addnode=185.225.232.141:16125
addnode=95.216.124.220:16125
addnode=209.145.55.52:16125
addnode=78.113.97.147:16125
addnode=209.145.49.181:16125
EOF

cd /root/bitcore-node/bin/mynode/node_modules
git clone https://github.com/runonflux/insight-api
git clone https://github.com/runonflux/insight-ui
cd insight-api
npm install
cd ..
cd insight-ui
npm install
fi

cd /root/bitcore-node/bin/mynode
while true; do
echo -e "Starting flux explorer...."
../bitcore-node start
sleep 60
done