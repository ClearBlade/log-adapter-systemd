#!/usr/bin/env bash

function usage() {
  local just_help=$1
  local missing_required=$2
  local invalid_option=$3
  local invalid_argument=$4

  local help="Usage: clearblade.sh [OPTIONS]

[ENTER YOUR DESCRIPTION HERE]

Example: edge.sh [ENTER YOUR EXAMPLE ARGUMENTS HERE]

Options (* indicates it is required):
        --cb-src string        [ENTER YOUR DESCRIPTION HERE]
        --cb-nodes string      [ENTER YOUR DESCRIPTION HERE]
        --cb-version string    [ENTER YOUR DESCRIPTION HERE]
        --id string            [ENTER YOUR DESCRIPTION HERE]
    -h, --help                 Displays this usage text.
"

  if [ "$just_help" != "" ]
  then
    echo "$help"
    return
  fi

  if [ "$missing_required" != "" ]
  then
    echo "Missing required argument: $missing_required"
  fi

  if [ "$invalid_option" != "" ] && [ "$invalid_value" = "" ]
  then
    echo "Invalid option: $invalid_option"
    return
  elif [ "$invalid_value" != "" ]
  then
    echo "Invalid value: $invalid_value for option: --$invalid_option"
  fi

  echo -e "\n"
  echo "$help"
  return
}

ALL_ARGS=("platform-ip" "parent-system" "edge-ip" "edge-id" "edge-cookie")
REQ_ARGS=("platform-ip" "parent-system" "edge-ip" "edge-id" "edge-cookie")

# get command line arguments
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -h|--help)
    usage 1
    exit
    ;;
    --platform-ip)
    platform_ip="$2"
    shift 2
    ;;
    --parent-system)
    parent_system="$2"
    shift 2
    ;;
    --edge-ip)
    edge_ip="$2"
    shift 2
    ;;
    --edge-id)
    edge_id="$2"
    shift 2
    ;;
    --edge-cookie)
    edge_cookie="$2"
    shift 2
    ;;
    *)
    usage "" "" "$1"
    shift
    ;;
esac
done

for i in "${REQ_ARGS[@]}"; do
  # $i is the string of the variable name
  # ${!i} is a parameter expression to get the value
  # of the variable whose name is i.
  req_var=${!i}
  if [ "$req_var" = "" ]
  then
    usage "" "--$i"
    exit
  fi
done

for i in "${ALL_ARGS[@]}"; do
  # $i is the string of the variable name
  # ${!i} is a parameter expression to get the value
  # of the variable whose name is i.
  var_val=${!i}
  echo "$i:\"$var_val\""
done

# ACTUAL SCRIPT GOES HERE

echo "Setting Configurations..."
#---------Edge Version---------
EDGE_BIN="/usr/local/bin/edge"

#---------Systemd Configuration---------
SYSTEMD_PATH="/lib/systemd/system"
SYSTEMD_SERVICE_NAME="clearblade_edge.service"
SERVICE_NAME="ClearBlade Edge Service"

#-----Database Config-------
DATABASE_DIR="/srv/clearblade/db"
DATASTORE="-db=sqlite -sqlite-path=$DATABASE_DIR/edge.db -sqlite-path-users=$DATABASE_DIR/edgeusers.db"

#-----Edge Params-----------
DEFAULT_EDGE_PARAMS="-platform-ip=$platform_ip -parent-system=$parent_system -edge-ip=$edge_ip -edge-id=$edge_id -edge-cookie=$edge_cookie"
EDGE_PARAMS="$DEFAULT_EDGE_PARAMS $DATASTORE"


echo "--------Configuration Check-----------"
echo "$EDGE_PARAMS"
echo "Systemd Path: $SYSTEMD_PATH"
echo "Systemd Service Name: $SYSTEMD_SERVICE_NAME"
echo "Systemd Service Description: $SERVICE_NAME"
echo "Edge's Database Dir: $DATABASE_DIR"
echo "Edge Database Command: $DATASTORE"



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
Description=$SERVICE_NAME 
After=network.target
[Service]
Type=simple
User=root
ExecStart=$EDGE_BIN $EDGE_PARAMS
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