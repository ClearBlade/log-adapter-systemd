#!/usr/bin/env python
import argparse, sys, time, subprocess, logging, json, os
import datetime
import select
import pprint
import random
from systemd import journal
from clearblade.ClearBladeCore import System
from uuid import UUID

def parse_env_variables(env):
    """Parse environment variables"""
    possible_vars = ["CB_SYSTEM_KEY", "CB_SYSTEM_SECRET", "CB_EDGE_NAME", "CB_PLATFORM_IP", "CB_EDGE_IP", "CB_ADAPTERS_ROOT_DIR", "CB_SERVICE_ACCOUNT", "CB_SERVICE_ACCOUNT_TOKEN"]
    
    for var in possible_vars:
        if var in env:
            print("Setting config from environment variable: " + var)
            CB_CONFIG[var] = env[var]

    #TODO Add implementation specific environment variables here


def parse_args(argv):
    """Parse the command line arguments"""

    parser = argparse.ArgumentParser(description='ClearBlade Adapter')
    parser.add_argument('-systemKey', dest="CB_SYSTEM_KEY", help='The System Key of the ClearBlade \
                        Plaform "System" the adapter will connect to.')

    parser.add_argument('-systemSecret', dest="CB_SYSTEM_SECRET", help='The System Secret of the \
                        ClearBlade Plaform "System" the adapter will connect to.')

    parser.add_argument('-deviceID', dest="deviceID", help='The id/name of the device that will be used for device \
                        authentication against the ClearBlade Platform or Edge, defined \
                        within the devices table of the ClearBlade platform.')

    parser.add_argument('-activeKey', dest="activeKey", help='The active key of the device that will be used for device \
                        authentication against the ClearBlade Platform or Edge, defined within \
                        the devices table of the ClearBlade platform.')

    parser.add_argument('-cb_service_account', dest="CB_SERVICE_ACCOUNT", help='The id/name of the device service accountthat will be used for \
                        authentication against the ClearBlade Platform or Edge, defined \
                        within the devices table of the ClearBlade platform.')

    parser.add_argument('-cb_service_account_token', dest="CB_SERVICE_ACCOUNT_TOKEN", help='The token of the device service account that will be used for device \
                        authentication against the ClearBlade Platform or Edge, defined within \
                        the devices table of the ClearBlade platform.')

    parser.add_argument('-httpUrl', dest="httpURL", default="http://localhost", \
                        help='The HTTP URL of the ClearBlade Platform or Edge the adapter will \
                        connect to. The default is https://localhost.')

    parser.add_argument('-httpPort', dest="httpPort", default="9000", \
                        help='The HTTP Port of the ClearBlade Platform or Edge the adapter will \
                        connect to. The default is 9000.')

    parser.add_argument('-messagingUrl', dest="messagingURL", default="localhost", \
                        help='The MQTT URL of the ClearBlade Platform or Edge the adapter will \
                        connect to. The default is https://localhost.')

    parser.add_argument('-messagingPort', dest="messagingPort", type=int, default=1883, \
                        help='The MQTT Port of the ClearBlade Platform or Edge the adapter will \
                        connect to. The default is 1883.')

    parser.add_argument('-requestTopicRoot', dest="requestTopicRoot", default="edge/command/request", \
                        help='The MQTT topic this adapter will subscribe to in order to receive command requests. \
                        The default is "edge/command/request".')

    parser.add_argument('-responseTopicRoot', dest="responseTopicRoot", default="edge/command/response", \
                        help='The MQTT topic this adapter will publish to in order to send command responses. \
                        The default is "edge/command/response".')

    parser.add_argument('-logLevel', dest="logLevel", default="INFO", choices=['CRITICAL', \
                        'ERROR', 'WARNING', 'INFO', 'DEBUG'], help='The level of logging that \
                        should be utilized by the adapter. The default is "INFO".')

    parser.add_argument('-logCB', dest="logCB", default=False, action='store_true',\
                        help='Flag presence indicates logging information should be printed for \
                        ClearBlade libraries.')

    parser.add_argument('-logMQTT', dest="logMQTT", default=False, action='store_true',\
                        help='Flag presence indicates MQTT logs should be printed.')

    #TODO Add implementation specific command line arguments here

    args = vars(parser.parse_args(args=argv[1:]))
    for var in args:
        if args[var] != "" and args[var] != None:
            print("Setting config from command line argument: " + var)
            CB_CONFIG[var] = args[var]


def check_required_config():
    """Verify all required config options were provided via environment variables or command line arguments"""
    if "CB_SYSTEM_KEY" not in CB_CONFIG:
        logging.error("System Key is required, can be provided with CB_SYSTEM_KEY environment variable or --systemKey command line argument")
        exit(-1)
    if not "CB_SYSTEM_SECRET" in CB_CONFIG:
        logging.error("System Secret is required, can be provided with CB_SYSTEM_SECRET environment variable or --systemSecret command line argument")
        exit(-1)

    if "deviceID" in CB_CONFIG and CB_CONFIG["deviceID"] != "" and CB_CONFIG["deviceID"] != None:
        if "activeKey" not in CB_CONFIG:
            logging.error("Device Active Key is required when a deviceID is specified, can be provided with the --activeKey command line argument")
            exit(-1)
    elif "CB_SERVICE_ACCOUNT" in CB_CONFIG and CB_CONFIG["CB_SERVICE_ACCOUNT"] != "" and CB_CONFIG["CB_SERVICE_ACCOUNT"] != None:
        if "CB_SERVICE_ACCOUNT_TOKEN" not in CB_CONFIG:
            logging.error("Device Service Account Token is required when a Service Account is specified, can be provided with the CB_SERVICE_ACCOUNT_TOKEN enviornment variable or --cb_service_account_token command line argument")
            exit(-1)
    else:
        logging.error("Device ID/Active Key or Service Account Name and Token are required")
        exit(-1)
    logging.debug("Adapter Config Looks Good!")



# Create a systemd.journal.Reader instance
j = journal.Reader()

# Set the reader's default log level
j.log_level(journal.LOG_INFO)

# Only include entries since the current box has booted.
j.this_boot()
j.this_machine()

# Filter log entries
# SYSTEMD_SERVICE_NAME="clearblade_edge_logger.service"

#j.add_match(_SYSTEMD_UNIT=u'clearblade_edge.service')
#     SYSLOG_IDENTIFIER=u'myservice/module',
#     _COMM=u'myservicecommand'
# )

# Move to the end of the journal
j.seek_tail()

# Important! - Discard old journal entries
j.get_previous()

# Create a poll object for journal entries
p = select.poll()

# Register the journal's file descriptor with the polling object.
journal_fd = j.fileno()
poll_event_mask = j.get_events()
p.register(journal_fd, poll_event_mask)

class UUIDEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, UUID):
            # if the obj is uuid, we simply return the value of uuid
            return obj.hex
        return json.JSONEncoder.default(self, obj)

CB_CONFIG = {}

# Parse and Validate all args
parse_env_variables(os.environ)
parse_args(sys.argv)   
check_required_config()

# System credentials
CB_SYSTEM = System(CB_CONFIG['CB_SYSTEM_KEY'], CB_CONFIG['CB_SYSTEM_SECRET'], CB_CONFIG['httpURL'] + ":" + CB_CONFIG["httpPort"] )

uid = None

if 'deviceID' in CB_CONFIG:
    uid = CB_SYSTEM.Device(CB_CONFIG['deviceID'], CB_CONFIG['activeKey'])
elif 'CB_SERVICE_ACCOUNT' in CB_CONFIG:
    uid = CB_SYSTEM.Device(CB_CONFIG['CB_SERVICE_ACCOUNT'], authToken=CB_CONFIG['CB_SERVICE_ACCOUNT_TOKEN'])
else:
    print("Device Name/Active Key or Device Service Account/Token not provided")
    exit(-1)

mqtt = CB_SYSTEM.Messaging(uid, CB_CONFIG["messagingPort"], keepalive=30)


# Set up callback function


def on_connect(client, userdata, flags, rc):
    # When we connect to the broker, start publishing our data to the keelhauled topic
    print("Return Code: ", rc)
    if rc == 0:
        print('Successfully connected')
    #print('waiting ... %s' % datetime.datetime.now())


# Connect callback to client
mqtt.on_connect = on_connect

# Connect and spin for 30 seconds before disconnecting
mqtt.connect()
while True:
   if p.poll(1500):
       if j.process() == journal.APPEND:
           msg_logs = {}
           for entry in j:
               #print("Entry: ", type(entry))
               #pprint.pprint(entry)
               #result = json.dumps(entry, cls=UUIDEncoder)
               msg = entry['MESSAGE'].decode('utf-8').encode('ascii')
               entry_type = entry['_SYSTEMD_UNIT'].decode('utf-8').encode('ascii')
               if entry_type not in msg_logs:
                   msg_logs[entry_type] = []
               msg_logs[entry_type].append(msg)
               #print("Type of Msg", type(msg))
               #client.publish("logs", msg, 2)
           for key in msg_logs:
               if len(msg_logs[key]) != 0: 
               #msg_logs[key]
                   curr_interval_log = "\n".join(msg_logs[key])
                   #print("Key:", key,"Message:",curr_interval_log)
                   #pprint.pprint(curr_interval_log)
                   pub_key = key.split('.', 1)[0]
                   mqtt.publish(pub_key, curr_interval_log, 0)