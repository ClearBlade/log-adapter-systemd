#!/bin/bash
## Assumptions
## 1. Needs 'curl' if downloading & installing the edge.
## 2. Assumes Edge Binary exists in '/usr/local/bin/' as 'edge'
## 3. If downloading and installing edge binary, perform step 2 (Uncomment)
##    Perform Step 6

echo "Setting Configurations..."
#---------Edge Version---------
EDGE_BIN="/usr/local/bin/edge"
RELEASE="4.3.0"

#---------Edge Configuration---------
EDGE_COOKIE="<EDGE_COOKIE>" #Cookie from Edge Config Screen
EDGE_ID="<EDGE_ID>" #Edge Name when Created in the system
PARENT_SYSTEM="<PARENT_SYSTEM_KEY>" #System Key of the application to connect
PLATFORM_HOST_NAME="<PLATFORM_URL>" #FQDN Hostname to Connect

#---------WORKDIR-------------
WORK_DIR="/home/pi"

#---------Logging Info---------
LOG_LEVEL="info"

#---------Systemd Configuration---------
SYSTEMD_PATH="/lib/systemd/system"
SYSTEMD_SERVICE_NAME="clearblade.service"
SERVICE_NAME="ClearBlade Edge Service"

#-----Database Config-------
DATABASE_DIR="/srv/clearblade/db"
DATASTORE="-db=sqlite -sqlite-path=$DATABASE_DIR/edge.db -sqlite-path-users=$DATABASE_DIR/edgeusers.db"

echo "--------Configuration Check-----------"
echo "Edge Bin: $EDGE_BIN"
echo "Edge Release: $RELEASE"
echo "Edge Cookie: $EDGE_COOKIE"
echo "Edge Name (Exists in console's Edge Section): $EDGE_ID"
echo "Parent System Key: $PARENT_SYSTEM"
echo "Platform Host: $PLATFORM_HOST_NAME"
echo "Workdir, relevant if performing step 6: $WORK_DIR"
echo "Log Level: $LOG_LEVEL"
echo "Systemd Path: $SYSTEMD_PATH"
echo "Systemd Service Name: $SYSTEMD_SERVICE_NAME"
echo "Systemd Service Description: $SERVICE_NAME"
echo "Edge's Database Dir: $DATABASE_DIR"
echo "Edge Database Command: $DATASTORE"

echo "1. Installing Prereqs Skipping..."
# apt-get install sudo -y
#---------Pre Reqs-------------------
# sudo apt-get update -y
# sudo apt-get install curl -y

echo "2. Download and Install Edge, Skipping"
## Uncomment if needed

#######################################################
#---------Ensure your architecture is correct----------
#######################################################
#MACHINE_ARCHITECTURE="$(uname -m)"
#MACHINE_OS="$(uname)"
#echo "Machine Architecture: $MACHINE_ARCHITECTURE"
#if [ "$MACHINE_ARCHITECTURE" == "armv5tejl" ] ; then
#  ARCHITECTURE="edge-linux-armv5tejl.tar.gz"
#elif [ "$MACHINE_ARCHITECTURE" == "armv6l" ] ; then
#  ARCHITECTURE="edge-linux-armv6.tar.gz"
#elif [ "$MACHINE_ARCHITECTURE" == "armv7l" ] ; then
#  ARCHITECTURE="edge-linux-armv7.tar.gz"
#elif [ "$MACHINE_ARCHITECTURE" == "armv8" ] ; then
#  ARCHITECTURE="edge-linux-arm64.tar.gz"
#elif [ "$MACHINE_ARCHITECTURE" == "i686" ] ||  [ "$MACHINE_TYPE" == "i386" ] ; then
#  ARCHITECTURE="edge-linux-386.tar.gz"
#elif [ "$MACHINE_ARCHITECTURE" == "x86_64" ] && [ "$MACHINE_OS" == "Darwin" ] ; then
#  ARCHITECTURE="edge-darwin-amd64.tar.gz" 
#elif [ "$MACHINE_ARCHITECTURE" == "x86_64" ] && [ "$MACHINE_OS" == "Linux" ] ; then
#  ARCHITECTURE="edge-linux-amd64.tar.gz"
#else 
#  echo "---------Unknown Architecture Error---------"
#    echo "STOPPING: Validate Architecture of OS"
#    echo "-----------------------------------"
#  exit
#fi

#-----------Downloading Edge-----------
# echo "https://github.com/ClearBlade/Edge/releases/download/$RELEASE/$ARCHITECTURE"
# sudo curl -#SL -L "https://github.com/ClearBlade/Edge/releases/download/$RELEASE/$ARCHITECTURE" -o /tmp/$ARCHITECTURE

#-----------Extract & Install Edge------------
# tar xzvf "/tmp/$ARCHITECTURE"
#----- Remove (if any) previous edge version---
# sudo rm "$EDGE_BIN"
# rm "/tmp/$ARCHITECTURE"
# sudo ln -f "$WORK_DIR/edge-$RELEASE" "$EDGE_BIN"
# sudo chmod +x "$EDGE_BIN"

echo "3. Cleaning old systemd services and binaries..."
#echo "------Cleaning Up Old Configurations"
sudo systemctl stop "$SYSTEMD_SERVICE_NAME"
sudo systemctl disable "$SYSTEMD_SERVICE_NAME"
sudo rm "$SYSTEMD_PATH/$SYSTEMD_SERVICE_NAME"
sudo rm -rf "$SYSTEMD_SERVICE_NAME"

echo "4. Creating database directory in case it doesn't exist"
# creating database folder in case it doesn't exist.
sudo mkdir -p "$DATABASE_DIR"

echo "5. Creating clearblade service"

sudo cat >$SYSTEMD_SERVICE_NAME <<EOF
[Unit]
Description=$SERVICE_NAME Version: $RELEASE
After=network.target
[Service]
Type=simple
User=root
ExecStart=$EDGE_BIN -log-level=$LOG_LEVEL -novi-ip=$PLATFORM_HOST_NAME -parent-system=$PARENT_SYSTEM -edge-ip=localhost -edge-id=$EDGE_ID -edge-cookie=$EDGE_COOKIE $DATASTORE
Restart=always
TimeoutSec=30
RestartSec=30
StartLimitInterval=350
StartLimitBurst=10

[Install]
WantedBy=multi-user.target

EOF

echo "6. Placing service in systemd folder..."

sudo mv "$SYSTEMD_SERVICE_NAME" "$SYSTEMD_PATH"

echo "7. Setting Startup Options"
# systemd reload so that it no longer attempts to reference old versions.
sudo systemctl daemon-reload
sudo systemctl enable "$SYSTEMD_SERVICE_NAME"

echo "8. Starting the service..."
sudo systemctl start "$SYSTEMD_SERVICE_NAME"
echo "Using  'sudo journalctl -u clearblade.service -n 50' for status"
sudo journalctl -u clearblade.service -n 50