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
# main
#----------------------------------------------------------------------------
  get_apiserver_config

  install_dpackage curl
  install_dpackage apache2
  install_nodejs
  install_dpackage git

  clone_apiserver
  install_config
