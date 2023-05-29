#!/usr/bin/env bash
#color codes
RED='\033[1;31m'
YELLOW='\033[1;33m'
BLUE="\\033[38;5;27m"
SEA="\\033[38;5;49m"
GREEN='\033[1;32m'
CYAN='\033[1;36m'
NC='\033[0m'

#emoji codes
CHECK_MARK="${GREEN}\xE2\x9C\x94${NC}"
X_MARK="${RED}\xE2\x9C\x96${NC}"
PIN="${RED}\xF0\x9F\x93\x8C${NC}"
CLOCK="${GREEN}\xE2\x8C\x9B${NC}"
ARROW="${SEA}\xE2\x96\xB6${NC}"
BOOK="${RED}\xF0\x9F\x93\x8B${NC}"
HOT="${ORANGE}\xF0\x9F\x94\xA5${NC}"
WORNING="${RED}\xF0\x9F\x9A\xA8${NC}"
RIGHT_ANGLE="${GREEN}\xE2\x88\x9F${NC}"
server_offline="0"
failed_counter="0"


function tar_file_unpack()
{
    echo -e "${ARROW} ${CYAN}Unpacking bootstrap archive file...${NC}"
    pv $1 | tar -zx -C $2
}

function cdn_speedtest() {
        if [[ -z $1 || "$1" == "0" ]]; then
                BOOTSTRAP_FILE="flux_explorer_bootstrap.tar.gz"
        else
                BOOTSTRAP_FILE="$1"
        fi
        if [[ -z $2 ]]; then
                dTime="5"
        else
                dTime="$2"
        fi
        if [[ -z $3 ]]; then
                rand_by_domain=("5" "6" "7" "8" "9" "10" "11" "12")
        else
                msg="$3"
                shift
                shift
                rand_by_domain=("$@")
                custom_url="1"
        fi
        size_list=()
        i=0
        len=${#rand_by_domain[@]}
        echo -e "${ARROW} ${CYAN}Running quick download speed test for ${BOOTSTRAP_FILE}, Servers: ${GREEN}$len${NC}"
        start_test=`date +%s`
        while [ $i -lt $len ];
   do
                if [[ "$custom_url" == "1" ]]; then
                        testing=$(curl -m ${dTime} ${rand_by_domain[$i]}${BOOTSTRAP_FILE}  --output testspeed -fail --silent --show-error 2>&1)
                else
                        testing=$(curl -m ${dTime} http://cdn-${rand_by_domain[$i]}.runonflux.io/apps/fluxshare/getfile/${BOOTSTRAP_FILE}  --output testspeed -fail --silent --show-error 2>&1)
                fi
                testing_size=$(grep -Po "\d+" <<< "$testing" | paste - - - - | awk '{printf  "%d\n",$3}')
                mb=$(bc <<<"scale=2; $testing_size / 1048576 / $dTime" | awk '{printf "%2.2f\n", $1}')
                if [[ "$custom_url" == "1" ]]; then
                        domain=$(sed -e 's|^[^/]*//||' -e 's|/.*$||' <<< ${rand_by_domain[$i]})
                        echo -e "  ${RIGHT_ANGLE} ${GREEN}URL - ${YELLOW}${domain}${GREEN} - Bits Downloaded: ${YELLOW}$testing_size${NC} ${GREEN}Average speed: ${YELLOW}$mb ${GREEN}MB/s${NC}"
                else
                        echo -e "  ${RIGHT_ANGLE} ${GREEN}cdn-${YELLOW}${rand_by_domain[$i]}${GREEN} - Bits Downloaded: ${YELLOW}$testing_size${NC} ${GREEN}Average speed: ${YELLOW}$mb ${GREEN}MB/s${NC}"
                fi
                size_list+=($testing_size)
                if [[ "$testing_size" == "0" ]]; then
                        failed_counter=$(($failed_counter+1))
                fi
                i=$(($i+1))
        done
        rServerList=$((${#size_list[@]}-$failed_counter))
        echo -e "${ARROW} ${CYAN}Valid servers: ${GREEN}${rServerList} ${CYAN}- Duration: ${GREEN}$((($(date +%s)-$start_test)/60)) min. $((($(date +%s)-$start_test) % 60)) sec.${NC}"
        rm -rf testspeed > /dev/null 2>&1
        if [[ "$rServerList" == "0" ]]; then
        server_offline="1"
        return
        fi
        arr_max=$(printf '%s\n' "${size_list[@]}" | sort -n | tail -1)
        for i in "${!size_list[@]}"; do
                [[ "${size_list[i]}" == "$arr_max" ]] &&
                max_indexes+=($i)
        done
        server_index=${rand_by_domain[${max_indexes[0]}]}
        if [[ "$custom_url" == "1" ]]; then
                BOOTSTRAP_URL="$server_index"
        else
                BOOTSTRAP_URL="http://cdn-${server_index}.runonflux.io/apps/fluxshare/getfile/"
        fi
        DOWNLOAD_URL="${BOOTSTRAP_URL}${BOOTSTRAP_FILE}"
   #Print the results
        mb=$(bc <<<"scale=2; $arr_max / 1048576 / $dTime" | awk '{printf "%2.2f\n", $1}')
        if [[ "$custom_url" == "1" ]]; then
                domain=$(sed -e 's|^[^/]*//||' -e 's|/.*$||' <<< ${server_index})
                echo -e "${ARROW} ${CYAN}Best server is: ${YELLOW}${domain} ${GREEN}Average speed: ${YELLOW}$mb ${GREEN}MB/s${NC}"
        else
                echo -e "${ARROW} ${CYAN}Best server is: ${GREEN}cdn-${YELLOW}${rand_by_domain[${max_indexes[0]}]} ${GREEN}Average speed: ${YELLOW}$mb ${GREEN}MB/s${NC}"
        fi
   #echo -e "${CHECK_MARK} ${GREEN}Fastest Server: ${YELLOW}$DOWNLOAD_URL${NC}"
}

dpkg --configure -a
source ~/.bashrc
cd /data
#bash flux-fetch-params.sh > /dev/null 2>&1 && sleep 2
#curl -sL https://deb.nodesource.com/setup_8.x | bash - > /dev/null 2>&1
#apt-get install -y nodejs build-essential libzmq3-dev npm git > /dev/null 2>&1
apt update -y
apt install -y flux > /dev/null 2>&1


DBDIR="/data/bitcore-node/bin"
if [ -d $DBDIR ]; then
  echo "Directory $DBDIR already exists, we will not download bootstrap. Use hard redeploy if you want to apply a new bootstrap."
else
  #echo -e "${ARROW} ${YELLOW}Installing dependencies...${NC}"
  #curl -sL https://deb.nodesource.com/setup_8.x | bash - > /dev/null 2>&1
  #apt-get install -y nodejs build-essential libzmq3-dev npm git > /dev/null 2>&1
  #bitcore-node
  echo -e "${ARROW} ${YELLOW}Installing bitcore-node...${NC}"
  git clone https://github.com/runonflux/bitcore-node > /dev/null 2>&1
  cd bitcore-node
  npm install > /dev/null 2>&1
  cd bin
  chmod +x bitcore-node
  ./bitcore-node create mynode > /dev/null 2>&1
  cd mynode
  rm bitcore-node.json
  echo -e "${ARROW} ${YELLOW}Creating bitcore-node config file...${NC}"

  if [[ "$TESTNET" == "1" ]]; then
    NETWORK="testnet"
  else
    NETWORK="livenet"
  fi

  if [[ "$DB_COMPONENT_NAME" == "" ]]; then
  echo -e "${ARROW} ${CYAN}Set default value of DB_COMPONENT_NAME as host...${NC}"
  DB_COMPONENT_NAME="fluxmongodb_explorerflux"
  else
  echo -e "${ARROW} ${CYAN}DB_COMPONENT_NAME as host is ${GREEN}${DB_COMPONENT_NAME}${NC}"
  fi

cat << EOF > bitcore-node.json
{
  "network": "${NETWORK}",
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
                  "host": "${DB_COMPONENT_NAME}",
                  "port": "27017",
                  "database": "flux-api-${NETWORK}",
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

  #cp /usr/local/bin/fluxd /root/bitcore-node/bin/fluxd
  ln -s /usr/local/bin/fluxd /data/bitcore-node/bin/fluxd
  chmod +x /usr/local/bin/fluxd
  cd data
  echo -e "${ARROW} ${YELLOW}Creating flux daemon config file...${NC}"
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
maxconnections=10000
EOF

  if [[ "$TESTNET" == "1" ]]; then
    echo -e "testnet=1" >> flux.conf
    echo -e "addnode=testnet.runonflux.io" >> flux.conf
  else
   echo -e "addnode=explorer.zelcash.online" >> flux.conf
   echo -e "addnode=explorer.runonflux.io" >> flux.conf
   echo -e "addnode=blockbook.runonflux.io" >> flux.conf
   echo -e "addnode=explorer.flux.zelcore.io" >> flux.conf
  fi

  if [[ "$BOOTSTRAP" == "1" ]]; then
    echo -e ""
    cdn_speedtest "0" "6"
    if [[ "$server_offline" == "1" ]]; then
      echo -e "${WORNING} ${CYAN}All Bootstrap server offline, operation aborted.. ${NC}" && sleep 1
    else
      echo -e "${ARROW} ${YELLOW}Downloading File: ${GREEN}$DOWNLOAD_URL ${NC}"
      wget --tries 5 -O $BOOTSTRAP_FILE $DOWNLOAD_URL -q --no-verbose --show-progress --progress=dot:giga > /dev/null 2>&1
      tar_file_unpack "/data/bitcore-node/bin/mynode/data/$BOOTSTRAP_FILE" "/data/bitcore-node/bin/mynode/data"
      rm -rf /data/bitcore-node/bin/mynode/data/$BOOTSTRAP_FILE
      sleep 2
    fi
  fi
  echo -e ""
  cd /data/bitcore-node/bin/mynode/node_modules
  echo -e "${ARROW} ${YELLOW}Installing insight-api && insight-ui...${NC}"
  git clone https://github.com/runonflux/insight-api > /dev/null 2>&1
  git clone https://github.com/runonflux/insight-ui > /dev/null 2>&1
  cd insight-api
  npm install > /dev/null 2>&1
  cd ..
  cd insight-ui
  npm install > /dev/null 2>&1
fi

cd /data/bitcore-node/bin/mynode
while true; do
echo -e "${ARROW} ${YELLOW}Starting flux insight explorer...${NC}"
echo -e
../bitcore-node start
sleep 60
done
