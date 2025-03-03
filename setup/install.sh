#!/bin/bash
#
# Default Values

HOMEDIR=$(ls -d ~)
APPDIR=$HOMEDIR/Openframe-APIServer

#----------------------------------------------------------------------------
 function check_diskspace {
#----------------------------------------------------------------------------
# Make sure there is enough space to install the Openframe Frameconroller
  FREESPC=$(df / | tail -1 | tr -s " " | cut -d' ' -f4)
  if [ $FREESPC -lt 1048576 ]; then
    echo "Please make sure there are a least 1 GByte of free diskspace available"
    while [ 1 ]; do
      read -p "Do you want to try the extend the root filesystem to its maximum size (y/N): " EXTROOT
      [[ ! "$EXTROOT" =~ (^[Yy][Ee]?[Ss]?$)|(^[Nn][Oo]?$)|(^$) ]] && continue
      [ -z $EXTROOT ] && EXTROOT="N"
      break
    done

    if [[ $EXTROOT =~ ^[Yy] ]]; then
      curl -s https://raw.githubusercontent.com/mataebi/expand_rootfs/master/expand_rootfs | sudo bash
      exit 1
    fi
  fi
} # check_diskspace

#----------------------------------------------------------------------------
 function get_apiserver_config {
#----------------------------------------------------------------------------
# Get the information needed to configure the api server
  echo -e "\n***** Collecting configuration information"

  ### Get API server URL
  URLPAT='(^https?://[-A-Za-z0-9]+\.[-A-Za-z0-9\.]+(:[0-9]+)?$)|(^$)'

  [ -r $APPDIR/.env ] && API_FULLURL=$(grep "API_EXPOSED_URL=" "$APPDIR/.env" | tr -d "'" | cut -d"=" -f2 | cut -d"/" -f1-3)
  [ -z "$API_FULLURL" ] || [ "$API_FULLURL" == "null" ] && API_FULLURL="https://api.openframe.io"
  while [ 1 ]; do
    read -p "URL to be used for the API server ($API_FULLURL)? " NAPIFULLURL
    [[ ! "$NAPIFULLURL" =~ $URLPAT ]] && continue
    [ ! -z "$NAPIFULLURL" ] && API_FULLURL=$NAPIFULLURL
    break
  done

  API_SCHEMA=$(echo $API_FULLURL | cut -d":" -f1)
  API_HOST=$(echo $API_FULLURL | cut -d"/" -f3)
  API_DOMAINNAME=$(echo $API_HOST | rev | cut -d'.' -f1-2 | rev)
  API_SERVERNAME=$(echo $API_HOST | rev | cut -d'.' -f3- | rev)
  # Openframe API host to use. The path used will always be /v0
  API_PATH="/v0"
  API_EXPOSED_URL="${API_FULLURL}${API_PATH}"

  ### Ask for "internal" API server port number
  [ -r $APPDIR/.env ] && API_PORT=$(grep API_PORT "$APPDIR/.env" | sed "s/.*='*\([0-9]\+\).*/\1/")
  [ -z "$API_PORT" ] || [ "$API_PORT" == "null" ] && API_PORT="3000"
  while [ 1 ]; do
    read -p "Which port number should be used ($API_PORT): " NAPI_PORT
    [[ ! "$NAPI_PORT" =~ (^[0-9]+$)|(^$) ]] && continue
    [ ! -z $NAPI_PORT ] && [ $NAPI_PORT -gt 65535 ] && continue
    [ ! -z $NAPI_PORT ] && API_PORT=$NAPI_PORT
    break
  done

  # Ask for the SSL certificate path
  API_CERTPATH=/etc/ssl/certs/$API_HOST.crt
  while [ 1 ]; do
    read -p "Where can the SSL certificate be found ($API_CERTPATH): " NCERTPATH
    [ ! -z $NCERTPATH ] && API_CERTPATH=$NCERTPATH
    break
  done

  # Ask for the SSL private key path
  API_KEYPATH=/etc/ssl/private/$API_HOST.key
  while [ 1 ]; do
    read -p "Where can the SSL private key be found ($API_KEYPATH): " NKEYPATH
    [ ! -z $NKEYPATH ] && API_KEYPATH=$NKEYPATH
    break
  done

  # External host URLs used for e-mail confirmation links
  # The server cannot be started without these being specified (can even be a dummy)
  [ -r $APPDIR/.env ] && WEBAPPURL=$(grep "WEBAPP_EXPOSED_URL=" "$APPDIR/.env" | tr -d "'" | cut -d"=" -f2 | cut -d"/" -f1-3)
  [ -z "$WEBAPPURL" ] || [ "$WEBAPPURL" == "null" ] && WEBAPPURL="$API_SCHEMA://$API_DOMAINNAME"
  while [ 1 ]; do
    read -p "URL to be used for the web application server ($WEBAPPURL)? " NWEBAPPURL
    [[ ! "$NWEBAPPURL" =~ $URLPAT ]] && continue
    [ ! -z "$NWEBAPPURL" ] && WEBAPPURL=$NWEBAPPURL
    break
  done

  # E-Mail Server configuration
  LB_EMAIL_DS_CONNECTOR=mail
  LB_EMAIL_DS_NAME='Email'

  [ -r $APPDIR/.env ] && EMAILHOST=$(grep "LB_EMAIL_DS_HOST=" "$APPDIR/.env" | tr -d "'" | cut -d"=" -f2)
  [ -z "$EMAILHOST" ] || [ "$EMAILHOST" == "null" ] && EMAILHOST="mail.$API_DOMAINNAME"
  while [ 1 ]; do
    read -p "DNS name of the SMTP mail server to be used ($EMAILHOST)? " NEMAILHOST
    [[ ! "$NEMAILHOST" =~ (^[-a-z0-9]+\.[-a-z0-9\.]+$)|(^$) ]] && continue
    [ ! -z "$NEMAILHOST" ] && EMAILHOST=$NEMAILHOST
    break
  done

  LB_EMAIL_DS_TYPE='SMTP' # default

  ### Ask for mail server port number
  [ -r $APPDIR/.env ] && EMAILPORT=$(grep LB_EMAIL_DS_PORT "$APPDIR/.env" | sed "s/.*='*\([0-9]\+\).*/\1/")
  [ -z "$EMAILPORT" ] || [ "$EMAILPORT" == "null" ] && EMAILPORT="465"
  while [ 1 ]; do
    read -p "Which port number should be used for e-mail ($EMAILPORT): " NEMAILPORT
    [[ ! "$NEMAILPORT" =~ (^[0-9]+$)|(^$) ]] && continue
    [ ! -z $NEMAILPORT ] && [ $NEMAILPORT -gt 65535 ] && continue
    [ ! -z $NEMAILPORT ] && EMAILPORT=$NEMAILPORT
    break
  done

  ### Get E-Mail Username
  [ -r $APPDIR/.env ] && EMAILUSER=$(grep "LB_EMAIL_DS_USERNAME=" "$APPDIR/.env" | tr -d "'" | cut -d"=" -f2)
  [ -z "$EMAILUSER" ] || [ "$EMAILUSER" == "null" ] && EMAILUSER="nobody"
  while [ 1 ]; do
    read -p "E-Mail Server Username ($EMAILUSER)? " NEMAILUSER
    [[ ! "$NEMAILUSER" =~ (^[-a-zA-Z0-9\+\.]+$)|(^$) ]] && continue
    [ ! -z "$NEMAILUSER" ] && EMAILUSER=$NEMAILUSER
    break
  done

  ### Get E-Mail Password
  [ -r $APPDIR/.env ] && EMAILPASS=$(grep "LB_EMAIL_DS_PASSWORD=" "$APPDIR/.env" | tr -d "'" | cut -d"=" -f2)
  [ "$EMAILPASS" == "null" ] && EMAILPASS=""
  while [ 1 ]; do
    local HIDDEN=""
    [ ! -z "$EMAILPASS" ] && HIDDEN='*****'
    read -s -p "Enter the e-mail password for user $EMAILUSER ($HIDDEN): " NEMAILPASS
    echo
    [ ! -z "$NEMAILPASS" ] && EMAILPASS="$NEMAILPASS"
    [ -z "$EMAILPASS" ] && continue
    break
  done

  ### Get Pubsub server URL
  [ -r $APPDIR/.env ] && PS_FULLURL=$(grep "PS_EXPOSED_URL=" "$APPDIR/.env" | tr -d "'" | cut -d"=" -f2 | cut -d"/" -f1-3)
  [ -z "$PS_FULLURL" ] || [ "$PS_FULLURL" == "null" ] && PS_FULLURL="$API_FULLURL"
  while [ 1 ]; do
    read -p "URL to be used for the Pusub server ($PS_FULLURL)? " NPSFULLURL
    [[ ! "$NPSFULLURL" =~ $URLPAT ]] && continue
    [ ! -z "$NPSFULLURL" ] && PS_FULLURL=$NPSFULLURL
    break
  done

  PS_SCHEMA=$(echo $PS_FULLURL | cut -d":" -f1)
  PS_HOST=$(echo $PS_FULLURL | cut -d"/" -f3)
  PS_DOMAINNAME=$(echo $PS_HOST | rev | cut -d'.' -f1-2 | rev)
  PS_SERVERNAME=$(echo $PS_HOST | rev | cut -d'.' -f3- | rev)
  # Openframe Pubsub host to use. The path used will always be /faye
  PS_PATH='/faye'
  PS_EXPOSED_URL="${PS_FULLURL}${PS_PATH}"

  ### Ask for Pubsub server port number
  [ -r $APPDIR/.env ] && PS_PORT=$(grep PS_PORT "$APPDIR/.env" | sed "s/.*='*\([0-9]\+\).*/\1/")
  [ -z "$PS_PORT" ] || [ "$PS_PORT" == "null" ] && PS_PORT="3001"
  while [ 1 ]; do
    read -p "Which port number should be used ($PS_PORT): " NPS_PORT
    [[ ! "$NPS_PORT" =~ (^[0-9]+$)|(^$) ]] && continue
    [ ! -z $NPS_PORT ] && [ $NPS_PORT -gt 65535 ] && continue
    [ ! -z $NPS_PORT ] && PS_PORT=$NPS_PORT
    break
  done

  # Ask for the SSL certificate path
  PS_CERTPATH=/etc/ssl/certs/$PS_HOST.crt
  while [ 1 ]; do
    read -p "Where can the SSL certificate be found ($PS_CERTPATH): " NCERTPATH
    [ ! -z $NCERTPATH ] && PS_CERTPATH=$NCERTPATH
    break
  done

  # Ask for the SSL private key path
  PS_KEYPATH=/etc/ssl/private/$PS_HOST.key
  while [ 1 ]; do
    read -p "Where can the SSL private key be found ($PS_KEYPATH): " NKEYPATH
    [ ! -z $NKEYPATH ] && PS_KEYPATH=$NKEYPATH
    break
  done

  # [ -r $APPDIR/.env ] && PSURL=$(grep "PS_EXPOSED_URL=" "$APPDIR/.env" | tr -d "'" | cut -d"=" -f2)
  # [ -z "$PSURL" ] || [ "$PSURL" == "null" ] && PSURL="https://$API_SERVERNAME-ps.${API_DOMAINNAME}"
  # while [ 1 ]; do
  #   read -p "Full URL to be used for the pubsub server ($PSURL)? " NPSURL
  #   [[ ! "$NPSURL" =~ $URLPAT ]] && continue
  #   [ ! -z "$NPSURL" ] && PSURL=$NPSURL
  #   break
  # done
  # PS_PATH='/faye'
  # [[ ! "$PSURL" =~ $PS_PATH$ ]] && PSURL="${PSURL}${PS_PATH}"

  PS_API_TOKEN=$(uuid)

  # The file to be used to persist the memory db if any
  # LB_DB_MEM_FILE="$APPDIR/openframe_data.json"
  [ -r $APPDIR/.env ] && DBFILE=$(grep "LB_DB_MEM_FILE=" "$APPDIR/.env" | tr -d "'" | cut -d"=" -f2)
  [ -z "$DBFILE" ] || [ "$DBFILE" == "null" ] && DBFILE="$APPDIR/openframe_data.json"
  while [ 1 ]; do
    read -p "Full path of the file based database ($DBFILE)? " NDBFILE
    [[ ! "$NDBFILE" =~ (^[-a-zA-Z0-9/_.]+$)|(^$) ]] && continue
    [ ! -z "$NDBFILE" ] && DBFILE=$NDBFILE
    break
  done

  ### Ask for auto start at boot time
  while [ 1 ]; do
    read -p "Do you want to autostart the api server at boot time (Y/n): " AUTOSTART
    [[ ! "$AUTOSTART" =~ (^[Yy][Ee]?[Ss]?$)|(^[Nn][Oo]?$)|(^$) ]] && continue
    [ -z $AUTOSTART ] && AUTOSTART="Y"
    break
  done

  if [[ $AUTOSTART =~ ^[Yy] ]]; then
    AUTOSTART="true"
  else
    AUTOSTART="false"
  fi

  COOKIE_SECRECT=$(uuid)
} # get_apiserver_config

#----------------------------------------------------------------------------
 function install_nodejs {
#----------------------------------------------------------------------------
# Check if nodejs is already installed and install the current LTS release
# if this is not the case
  echo -e "\n***** Installing nodejs and npm"
  NPMVERS=$(npm --version 2>/dev/null)
  NODEVERS=$(node --version 2>/dev/null)

  if [ $? -gt 0 ] || [[ ! "$NODEVERS" =~ ^v1[4-9].*$ ]]; then
    curl -fsSL https://deb.nodesource.com/setup_14.x | sudo bash -
    sudo apt install -y nodejs
  else
    echo nodejs $NODEVERS and npm v$NPMVERS are already installed
  fi
} # install_install_nodejs

#----------------------------------------------------------------------------
 function install_dpackage {
#----------------------------------------------------------------------------
# Check if a specific Debian package is installed already and install it
# if this is not the case
  local DPACKAGE=$1

  echo -e "\n***** Installing $DPACKAGE"
  dpkg -s $DPACKAGE > /dev/null 2>&1;
  if [ $? -gt 0 ]; then
    sudo apt update && sudo apt install -y $DPACKAGE
  else
    echo $DPACKAGE is already installed
  fi
} # install_dpackage

#----------------------------------------------------------------------------
 function get_apiserver {
#----------------------------------------------------------------------------
# Clone or pull the API server repository
  echo -e "\n***** Installing Openframe API Server"
  cd $HOMEDIR/
  if [ ! -d $APPDIR/.git ]; then
    echo "Cloning https://github.com/mataebi/Openframe-APIServer.git"
    git clone --depth=1 --branch=master https://github.com/mataebi/Openframe-APIServer.git
  else
    echo "Updating from https://github.com/mataebi/Openframe-APIServer.git"
    cd $APPDIR
    git pull --depth=1
  fi
} # get_apiserver

#----------------------------------------------------------------------------
 function install_config {
#----------------------------------------------------------------------------
# Make sure the webapp configuration is initialized if needed
  echo -e "\n***** Installing initial configuration"
  if [ -r $APPDIR/.env ]; then
    echo "Backing up $APPDIR/.env"
    mv $APPDIR/.env $APPDIR/.env.bak
  fi
  echo "Writing $APPDIR/.env"

cat > "$APPDIR/.env" <<EOF
# Expose the API Server on this host and port
# The path used will always be /v0
API_HOST='$API_HOST'
API_PORT=$API_PORT

# External host URLs used for e-mail confirmation links
# The server cannot be started without these being specified (can even be a dummy)
API_EXPOSED_URL='$API_EXPOSED_URL'
WEBAPP_EXPOSED_URL='$WEBAPPURL'

# E-Mail Server configuration
LB_EMAIL_DS_CONNECTOR='mail'
LB_EMAIL_DS_NAME='Email'
LB_EMAIL_DS_HOST='$EMAILHOST'
LB_EMAIL_DS_TYPE='$LB_EMAIL_DS_TYPE'
LB_EMAIL_DS_PORT=$EMAILPORT
LB_EMAIL_DS_USERNAME='$EMAILUSER'
LB_EMAIL_DS_PASSWORD='$EMAILPASS'

# The Pubsub server configuration
# These values have to match PS_EXPOSED_URL below
PS_HOST='$PS_HOST'
PS_PORT=$PS_PORT
PS_PATH="/faye"
PS_EXPOSED_URL='$PS_EXPOSED_URL'
PS_API_TOKEN='$PS_API_TOKEN' # uuid

# The file to be used to persist the memory db if any
# This is not recommended for production use
LB_DB_MEM_FILE='$DBFILE'

# The database MongoDB server connector configuration
# For explanations see https://loopback.io/doc/en/lb3/MongoDB-connector.html#connection-properties
# LB_DB_DS_NAME='MongoDB'
# Must be mongodb
# LB_DB_DS_CONNECTOR='mongodb'
# LB_DB_DS_DATABASE='openframe'
# LB_DB_DS_DEBUG=''
# LB_DB_DS_HOST='localhost'
# MongoDB default port
# LB_DB_DS_PORT=27019
# Leave empty in most cases
# LB_DB_DS_URL=''
# LB_DB_DS_USERNAME=openframe
# use 'openssl rand -base64 12' to create a password
# LB_DB_DS_PASSWORD=RKSd7Rmi32yqNsKs

COOKIE_SECRECT='$COOKIE_SECRECT' # uuid
EOF
} # install_config

#----------------------------------------------------------------------------
 function build_apiserver {
#----------------------------------------------------------------------------
# Build the API server
  echo -e "\n***** Building the Openframe API Server"
  cd $APPDIR
  npm install
  npm audit fix
} # build_apiserver

#----------------------------------------------------------------------------
 function install_service {
#----------------------------------------------------------------------------
# Make sure the api server service is properly installed
  echo -e "\n***** Installing api server service"

  echo "Installing service at /lib/systemd/system/of-apiserver.service"
  local SERVICE_FILE=/usr/lib/systemd/system/of-apiserver.service
  sudo cp -p $APPDIR/setup/of-apiserver.service $SERVICE_FILE
  sudo sed -i "s|<user>|$(id -un)|g" $SERVICE_FILE
  # sudo sed -i "s|<configdir>|$APPDIR|g" $SERVICE_FILE
  sudo sed -i "s|<appdir>|$APPDIR|g" $SERVICE_FILE
  sudo systemctl daemon-reload

  if [ $AUTOSTART == "true" ]; then
    echo "Enabling autostart of service"
    sudo systemctl enable of-apiserver.service
  else
    echo "Disabling autostart of service"
    sudo systemctl disable of-apiserver.service
  fi
  sudo systemctl enable systemd-networkd-wait-online.service
} # install_service

#----------------------------------------------------------------------------
 function install_proxies {
#----------------------------------------------------------------------------
# Install and activate the  proxy server config for the API and the PubSub service
  echo -e "\n***** Installing proxy server configurations"

  local DSTFILE=/etc/apache2/sites-available/$API_HOST.conf
  echo -e "Setting up API proxy at $DSTFILE"
  sudo cp -p $APPDIR/setup/apiserver.example.com-ssl.conf $DSTFILE
  sudo sed -i "s|<certpath>|$API_CERTPATH|g" $DSTFILE
  sudo sed -i "s|<keypath>|$API_KEYPATH|g" $DSTFILE

  # Adjust the api server apache config file
  sudo sed -i "s|<apifullname>|$API_HOST|g" $DSTFILE
  sudo sed -i "s|<apiport>|$API_PORT|g" $DSTFILE

  [ -r $DSTFILE ] && sudo /usr/sbin/a2ensite $API_HOST.conf

  DSTFILE=/etc/apache2/sites-available/$PS_HOST.conf
  echo -e "\nSetting up PubSub proxy at $DSTFILE"
  sudo cp -p $APPDIR/setup/pubsubserver.example.com-ssl.conf $DSTFILE
  sudo sed -i "s|<certpath>|$PS_CERTPATH|g" $DSTFILE
  sudo sed -i "s|<keypath>|$PS_KEYPATH|g" $DSTFILE

  # Adjust the pubsub server apache config file
  sudo sed -i "s|<psfullname>|$PS_HOST|g" $DSTFILE
  sudo sed -i "s|<psport>|$PS_PORT|g" $DSTFILE

  [ -r $DSTFILE ] && sudo /usr/sbin/a2ensite $PS_HOST.conf

  sudo a2enmod ssl
  sudo a2enmod rewrite
  sudo service apache2 restart
} # install_proxies

#----------------------------------------------------------------------------
 function centertxt {
#----------------------------------------------------------------------------
  [ ! "$TXT" == " " ] && TXT="$TXT\n"
  LEN=$(( ($WIDTH - ${#1} - 4) / 2 - 1 ))
  TXT=$(perl -e "print (\"$TXT\", \" \"x$LEN, \"$1\");")
} # centertxt

#----------------------------------------------------------------------------
 function final_message {
#----------------------------------------------------------------------------
  WIDTH=70
  HEIGHT=12
  TXT=" "

  centertxt "Installation complete. To start the API server execute"
  TXT="$TXT\n"
  centertxt "'sudo service of-apiserver start'"
  TXT="$TXT\n"
  centertxt "then wait a few seconds for the service to start"

  whiptail --msgbox "$TXT" $HEIGHT $WIDTH
} # final_message

#----------------------------------------------------------------------------
# main
#----------------------------------------------------------------------------
  check_diskspace

  get_apiserver_config

  install_dpackage curl
  install_dpackage apache2
  install_dpackage git
  install_dpackage python
  install_dpackage build-essential
  install_nodejs

  get_apiserver
  install_config
  build_apiserver
  install_service
  install_proxies

  echo
  echo '*************************************************************'
  echo '*                                                           *'
  echo '*  Installation complete. To start the API server execute   *'
  echo '*             "sudo service of-apiserver start"             *'
  echo '*     then wait a few seconds for the service to start     *'
  echo '*                                                           *'
  echo '*************************************************************'
  echo
