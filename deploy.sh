#!/bin/bash
## Assumptions
## 1. Needs 'curl' if downloading & installing the edge.
## 2. Assumes Edge Binary exists in '/usr/local/bin/' as 'edge'
## 3. If downloading and installing edge binary, perform step 2 (Uncomment)
##    Perform Step 6

echo "Setting Configurations..."
#---------Edge Version---------
# EDGE_BIN="/usr/local/bin/edge"
# RELEASE="4.3.0"

#---------Edge Configuration---------
# EDGE_COOKIE="<EDGE_COOKIE>" #Cookie from Edge Config Screen
# EDGE_ID="<EDGE_ID>" #Edge Name when Created in the system
# PARENT_SYSTEM="<PARENT_SYSTEM_KEY>" #System Key of the application to connect
# PLATFORM_HOST_NAME="<PLATFORM_URL>" #FQDN Hostname to Connect

#---------WORKDIR-------------
WORK_DIR=/home/yashjain/edge-demo/adapters/log-adapter
REL_PROG_PATH="log_publisher.py"
#---------Logging Info---------
LOG_LEVEL="info"

#---------Systemd Configuration---------
SYSTEMD_PATH="/lib/systemd/system"
SYSTEMD_SERVICE_NAME="clearblade_edge_logger.service"
SERVICE_NAME="ClearBlade Edge Logger Service"

echo "--------Configuration Check-----------"

echo WORK_DIR: $WORK_DIR
#--------System Adapter Variables-------
echo CB_SYSTEM_KEY: $CB_SYSTEM_KEY
echo CB_SYSTEM_SECRET: $CB_SYSTEM_SECRET
echo CB_EDGE_NAME: $CB_EDGE_NAME
echo CB_EDGE_IP: $CB_EDGE_IP
echo CB_PLATFORM_IP: $CB_PLATFORM_IP
echo CB_ADAPTERS_ROOT_DIR: $CB_ADAPTERS_ROOT_DIR
echo CB_SERVICE_ACCOUNT: $CB_SERVICE_ACCOUNT
echo CB_SERVICE_ACCOUNT_TOKEN: $CB_SERVICE_ACCOUNT_TOKEN






echo "Workdir, relevant if performing step 6: $WORK_DIR"
echo "Log Level: $LOG_LEVEL"
echo "Systemd Path: $SYSTEMD_PATH"
echo "Systemd Service Name: $SYSTEMD_SERVICE_NAME"
echo "Systemd Service Description: $SERVICE_NAME"

echo "3. Cleaning old systemd services and binaries..."
#echo "------Cleaning Up Old Configurations"
sudo systemctl stop "$SYSTEMD_SERVICE_NAME"
sudo systemctl disable "$SYSTEMD_SERVICE_NAME"
sudo rm "$SYSTEMD_PATH/$SYSTEMD_SERVICE_NAME"
sudo rm -rf "$SYSTEMD_SERVICE_NAME"


echo "5. Creating clearblade logger service"
script_args="-systemKey $CB_SYSTEM_KEY -systemSecret $CB_SYSTEM_SECRET -cb_service_account $CB_SERVICE_ACCOUNT -cb_service_account_token $CB_SERVICE_ACCOUNT_TOKEN"
sudo cat >$SYSTEMD_SERVICE_NAME <<EOF
[Unit]
Description=$SERVICE_NAME
After=network.target
[Service]
Type=simple
User=root
ExecStart=/usr/bin/python $WORK_DIR/$REL_PROG_PATH $script_args
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
sudo journalctl -u $SYSTEMD_SERVICE_NAME -n 50