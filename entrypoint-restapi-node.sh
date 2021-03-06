#!/bin/bash
#HTTP_ADDR=http://172.17.0.1
OUTPUT_FILE=/bitprim/conf/bitprim-restapi.cfg
#OUTPUT_FILE=./bitprim-node.cfg
[ ! -n "$CONFIG_REPO" ] && CONFIG_REPO=https://github.com/bitprim/bitprim-config.git



log()
{
echo $(date +"%Y-%m-%d %H:%M:%S") $@
}



install_packages()
{
if [ ! -e /tmp/already_installed ] ; then
    apt-get update
    apt-get -y install git $ADDITIONAL_PACKAGES 
    if [ $? -eq 0 ] ; then
	echo "$ADDITIONAL_PACKAGES installed" >/tmp/already_installed
    fi
fi
}


clone_repo()
{
if [ -d "/bitprim/bitprim-config/.git" ] ; then
log "Refreshing $CONFIG_REPO Files on /bitprim/bitprim-config"
cd /bitprim/bitprim-config && git pull
else
log "Cloning $CONFIG_REPO to /bitrpim/bitprim-config"
git clone ${CONFIG_REPO} /bitprim/bitprim-config
fi
}


copy_config()
{
cd /bitprim 
mkdir -p /bitprim/{conf,log,database,bin}
if [ -n "$CONFIG_FILE" ] ; then
echo "Copying Bitprim Node Config ${CONFIG_FILE} from repo (CONFIG_FILE variable found)"
cp bitprim-config/$CONFIG_FILE ${OUTPUT_FILE}

else
[ ! -n "$COIN" ] && COIN=bch
[ ! -n "$NETWORK" ] && NETWORK=mainnet
echo "Copying default Bitprim Node config bitprim-restapi-${COIN}-${NETWORK}.cfg from repo"
cp bitprim-config/bitprim-restapi-${COIN}-${NETWORK}.cfg  ${OUTPUT_FILE}
fi

DB_DIR=$(sed -nr "/^\[database\]/ { :l /^directory[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" $OUTPUT_FILE)

}

clean_db_directory()
{
if [ -d "${DB_DIR}" ] ; then
  if [ ! -e /tmp/cleaned_db_directory ] ; then
  echo "Cleaning up database directory"
  rm -rf "${DB_DIR:?}"/* && rmdir "$DB_DIR"
  [ $? -eq 0 ] && touch /tmp/cleaned_db_directory
  fi
fi


}

_term() {
  echo "Caught SIGTERM signal!"
  echo "Waiting for $child"
  kill -TERM "$child" ; wait $child 2>/dev/null
}

start_bitprim()
{
cd /bitprim/bitprim-insight/bitprim.insight
echo "Starting REST-API Node"
trap _term SIGTERM

if [ -e "$DB_DIR/exclusive_lock" ] ; then
echo "Removing exclusive_lock file"
rm -f $DB_DIR/exclusive_lock
fi

log "Starting REST-API"
if [ -e /bitprim/bitprim-insight/bitprim.insight/build_complete ] ; then
dotnet bin/x64/Release/netcoreapp2.0/bitprim.insight.dll --server.port="$SERVER_PORT" --server.address=0.0.0.0 &
child=$!
echo "Started dotnet process PID=$child"
wait $child
else
log "build_complete flag not present, sleeping for 10 seconds and retrying "
sleep 10
start_bitprim
fi
}

### WORK Starts Here
shopt -s nocasematch
install_packages
clone_repo
copy_config
case "$CLEAN_DB_DIRECTORY" in
yes|y|true|1)
echo "Cleaning DB Directory before starting node"
clean_db_directory
;;
esac
[ "$CLEAN_DB_DIRECTORY" == "true" ] && clean_db_directory
start_bitprim
sleep 120