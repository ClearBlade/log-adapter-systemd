#!/bin/bash

echo Starting my adapter on edge $CB_EDGE_NAME

echo "1. Starting the service..."
SYSTEMD_SERVICE_NAME="clearblade_edge_logger.service"

echo $CB_SYSTEM_KEY
echo $CB_SYSTEM_SECRET
echo $CB_EDGE_NAME
echo $CB_EDGE_IP
echo $CB_PLATFORM_IP
echo $CB_ADAPTERS_ROOT_DIR
echo $CB_SERVICE_ACCOUNT
echo $CB_SERVICE_ACCOUNT_TOKEN


sudo systemctl start "$SYSTEMD_SERVICE_NAME"
