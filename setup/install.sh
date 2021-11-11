#!/bin/bash
#
# Default Values

HOMEDIR=$(ls -d ~)
APPDIR=$HOMEDIR/Openframe-APIServer

#----------------------------------------------------------------------------
 function get_apiserver_config {
#----------------------------------------------------------------------------
# Get the information needed to configure the api server
  echo -e "\n***** Collecting configuration information"

  ### Get API server URL
  URLPAT='(^https?://[-A-Za-z0-9]+\.[-A-Za-z0-9\.]+(:[0-9]+)?$)|(^$)'

  [ -r $APPDIR/.env ] && FULLURL=$(grep API_EXPOSED_URL "$APPDIR/.env" | tr -d "'" | cut -d"=" -f2 | cut -d"/" -f1-3)
  [ -z "$FULLURL" ] || [ "$FULLURL" == "null" ] && FULLURL="https://api.openframe.io"
  while [ 1 ]; do
    read -p "URL to be used for the API server ($FULLURL)? " NFULLURL
    [[ ! "$NFULLURL" =~ $URLPAT ]] && continue
    [ ! -z "$NFULLURL" ] && FULLURL=$NFULLURL
    break
  done

  SCHEMA=$(echo $FULLURL | cut -d":" -f1)
  API_HOST=$(echo $FULLURL | cut -d"/" -f3)
  DOMAINNAME=$(echo $API_HOST | rev | cut -d'.' -f1-2 | rev)
  SERVERNAME=$(echo $API_HOST | rev | cut -d'.' -f3- | rev)
  # Openframe API host to use. The path used will always be /v0
  API_EXPOSED_URL="$FULLURL/v0"

  ### Ask for API server port number
  [ -r $APPDIR/.env ] && API_PORT=$(grep API_PORT "$APPDIR/.env" | sed "s/.*='*\([0-9]\+\).*/\1/")
  [ -z "$API_PORT" ] || [ "$API_PORT" == "null" ] && API_PORT="8888"
  while [ 1 ]; do
    read -p "Which port number should be used ($API_PORT): " NAPI_PORT
    [[ ! "$NAPI_PORT" =~ (^[0-9]+$)|(^$) ]] && continue
    [ ! -z $NAPI_PORT ] && API_PORT=$NAPI_PORT
    break
  done

  # External host URLs used for e-mail confirmation links
  # The server cannot be started without these being specified (can even be a dummy)
  # WEBAPP_EXPOSED_URL='https://oframe.jabr.ch'
  [ -r $APPDIR/.env ] && WEBAPPURL=$(grep WEBAPP_EXPOSED_URL "$APPDIR/.env" | tr -d "'" | cut -d"=" -f2 | cut -d"/" -f1-3)
  [ -z "$WEBAPPURL" ] || [ "$WEBAPPURL" == "null" ] && WEBAPPURL="https://openframe.io"
  while [ 1 ]; do
    read -p "URL to be used for the web application server ($WEBAPPURL)? " NWEBAPPURL
    [[ ! "$NWEBAPPURL" =~ $URLPAT ]] && continue
    [ ! -z "$NWEBAPPURL" ] && WEBAPPURL=$NWEBAPPURL
    break
  done

  # E-Mail Server configuration
  LB_EMAIL_DS_CONNECTOR=mail
  LB_EMAIL_DS_NAME='Email'

  [ -r $APPDIR/.env ] && EMAILHOST=$(grep LB_EMAIL_DS_HOST "$APPDIR/.env" | tr -d "'" | cut -d"=" -f2)
  [ -z "$EMAILHOST" ] || [ "$EMAILHOST" == "null" ] && EMAILHOST="mail.$DOMAINNAME"
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
    [ ! -z $NEMAILPORT ] && EMAILPORT=$NEMAILPORT
    break
  done

  ### Get E-Mail Username
  [ -r $APPDIR/.env ] && EMAILUSER=$(grep LB_EMAIL_DS_USERNAME "$APPDIR/.env" | tr -d "'" | cut -d"=" -f2)
  [ -z "$EMAILUSER" ] || [ "$EMAILUSER" == "null" ] && EMAILUSER="nobody"
  while [ 1 ]; do
    read -p "E-Mail Server Username ($EMAILUSER)? " NEMAILUSER
    [[ ! "$NEMAILUSER" =~ (^[-a-zA-Z0-9\+\.]+$)|(^$) ]] && continue
    [ ! -z "$NEMAILUSER" ] && EMAILUSER=$NEMAILUSER
    break
  done

  ### Get E-Mail Password
  [ -r $APPDIR/.env ] && EMAILPASS=$(grep LB_EMAIL_DS_PASSWORD "$APPDIR/.env" | tr -d "'" | cut -d"=" -f2)
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

  # The Pubsub server configuration
  # Make sure the values match with PS_EXPOSED_URL
  PS_HOST=$API_HOST

  ### Ask for Pubsub server port number
  [ -r $APPDIR/.env ] && PS_PORT=$(grep PS_PORT "$APPDIR/.env" | sed "s/.*='*\([0-9]\+\).*/\1/")
  [ -z "$PS_PORT" ] || [ "$PS_PORT" == "null" ] && PS_PORT="8899"
  while [ 1 ]; do
    read -p "Which port number should be used ($PS_PORT): " NPS_PORT
    [[ ! "$NPS_PORT" =~ (^[0-9]+$)|(^$) ]] && continue
    [ ! -z $NPS_PORT ] && PS_PORT=$NPS_PORT
    break
  done

  # PS_EXPOSED_URL='https://oframe-ps.jabr.ch/faye'
  [ -r $APPDIR/.env ] && PSURL=$(grep PS_EXPOSED_URL "$APPDIR/.env" | tr -d "'" | cut -d"=" -f2)
  [ -z "$PSURL" ] || [ "$PSURL" == "null" ] && PSURL="https://$SERVERNAME-ps.${DOMAINNAME}"
  while [ 1 ]; do
    read -p "Full URL to be used for the pubsub server ($PSURL)? " NPSURL
    [[ ! "$NPSURL" =~ $URLPAT ]] && continue
    [ ! -z "$NPSURL" ] && PSURL=$NPSURL
    break
  done
  PS_PATH='/faye'
  PSURL="${PSURL}${PS_PATH}"

  PS_API_TOKEN=$(uuid)

  # The file to be used to persist the memory db if any
  # LB_DB_MEM_FILE="$APPDIR/openframe_data.json"
  [ -r $APPDIR/.env ] && DBFILE=$(grep LB_DB_MEM_FILE "$APPDIR/.env" | tr -d "'" | cut -d"=" -f2)
  [ -z "$DBFILE" ] || [ "$DBFILE" == "null" ] && DBFILE="$APPDIR/openframe_data.json"
  while [ 1 ]; do
    read -p "Full path of the file based database ($DBFILE)? " NDBFILE
    [[ ! "$NDBFILE" =~ [-a-zA-Z0-9_\.] ]] && continue
    [ ! -z "$NDBFILE" ] && DBFILE=$NDBFILE
    break
  done

  COOKIE_SECRECT=$(uuid)

  echo -e "FULLURL: $FULLURL\nSCHEMA: $SCHEMA\nAPI_HOST: $API_HOST\nDOMAINNAME: $DOMAINNAME"
  echo -e "SERVERNAME: $SERVERNAME\nAPI_EXPOSED_URL: $API_EXPOSED_URL\nAPI_PORT: $API_PORT"
  echo -e "WEBAPP_EXPOSED_URL: $WEBAPPURL\nLB_EMAIL_DS_HOST: $EMAILHOST\nLB_EMAIL_DS_USERNAME: $EMAILUSER"
  echo -e "LB_EMAIL_DS_PORT: $EMAILPORT\nLB_EMAIL_DS_PASSWORD: $EMAILPASS"
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
 function clone_apiserver {
#----------------------------------------------------------------------------
# Clone the API server repository
  echo -e "\n***** Cloning Openframe API Server"
  cd $HOMEDIR/
  git clone --depth=1 --branch=master https://github.com/mataebi/Openframe-APIServer.git
} # clone_apiserver

#----------------------------------------------------------------------------
 function install_config {
#----------------------------------------------------------------------------
# Make sure the webapp configuration is initialized if needed
  echo -e "\n***** Installing initial configuration"
  echo "Updating $APPDIR/.env"
  # echo "API_HOST=$API_BASE/v0/" > "$APPDIR/.env"
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
# main
#----------------------------------------------------------------------------
  get_apiserver_config
  exit

  install_dpackage curl
  install_dpackage apache2
  install_nodejs
  install_dpackage git
  install_dpackage build-essential
  install_dpackage python

  clone_apiserver
  install_config
  build_apiserver
