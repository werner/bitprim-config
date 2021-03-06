#!/bin/bash
#HTTP_ADDR=http://172.17.0.1
OUTPUT_FILE=/bitprim/conf/bitprim-restapi.cfg
#OUTPUT_FILE=./bitprim-node.cfg
[ ! -n "$CONFIG_REPO" ] && CONFIG_REPO=https://github.com/bitprim/bitprim-config.git
[ ! -n "$APP_REPO" ] && APP_REPO=https://github.com/bitprim/bitprim-insight

install_packages()
{
if [ ! -e /tmp/already_installed ] ; then
    apt-get update
    apt-get -y install cmake build-essential python-pip $ADDITIONAL_PACKAGES 
    apt-get -y remove python-pip
    easy_install pip && pip install conan &&  conan remote add bitprim https://api.bintray.com/conan/bitprim/bitprim
    if [ $? -eq 0 ] ; then
	echo "$ADDITIONAL_PACKAGES installed" >/tmp/already_installed
    fi
fi
}

copy_config()
{
cd /bitprim 

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



if [ -n "$APP_CONFIG_FILE" ] ; then
echo "Copying REST API App  Config ${APP_CONFIG_FILE} from repo (CONFIG_FILE variable found)"
cp bitprim-config/$APP_CONFIG_FILE /bitprim/bitprim-insight/bitprim.insight/appsettings.json

else

shopt -s nocasematch
case $FULL_NODE in
yes|y|true|1)
echo "Copying default REST API Full Node config bitprim-restapi-${COIN}-${NETWORK}.cfg from repo"
cp bitprim-config/appsettings-node.json /bitprim/bitprim-insight/bitprim.insight/appsettings.json


;;

*)
echo "Copying default REST API Forwarder Node config bitprim-restapi-${COIN}-${NETWORK}.cfg from repo"
cp bitprim-config/appsettings-fwd.json /bitprim/bitprim-insight/bitprim.insight/appsettings.json
echo "Configuring FORWARD_URL:$FORWARD_URL in appsettings.json"
sed -i "s#%FORWARD_URL%#${FORWARD_URL}#g" /bitprim/bitprim-insight/bitprim.insight/appsettings.json

;;
esac



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

echo "Cleaning Conan cache"
conan remove --force '*' 
conan remote remove conan-center
conan remote remove conan-transit
dotnet build /property:Platform=x64 /p:${COIN^^}=true -c Release -f netcoreapp2.0 -v normal
dotnet bin/x64/Release/netcoreapp2.0/bitprim.insight.dll --server.port="$SERVER_PORT" --server.address=0.0.0.0 &
child=$!
echo "Started dotnet process PID=$child"
wait $child

}

### WORK Starts Here
shopt -s nocasematch
install_packages
copy_config
case "$CLEAN_DB_DIRECTORY" in
yes|y|true|1)
echo "Cleaning DB Directory before starting node"
clean_db_directory
;;
esac
[ "$CLEAN_DB_DIRECTORY" == "true" ] && clean_db_directory
start_bitprim
sleep 20000