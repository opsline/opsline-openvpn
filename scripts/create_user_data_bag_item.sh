#!/usr/bin/env bash

set -e

function show_help {
    echo ""
    echo "$(basename $0)"
    echo "  -h"
    echo "  -s <vpn server node name>"
    echo "  -u <user name>"
    echo "  -d <databag name>"
    echo "  -k <encrypted data bag secret file>"
    echo "  [-i <vpn server instance name>]"
    echo "  [-x <ssh user name>]"
    echo "  [-a <ssh host attribute>]"
}

INSTANCE=""
SSH_USER_NAME=$USER
SSH_HOST_ATTRIBUTE="ec2.public_ipv4"

while getopts "hs:u:d:k:i:x:a:" opt; do
    case "$opt" in
    h)
        show_help
        exit 0
        ;;
    s)
        VPN_SERVER_NODENAME=$OPTARG
        ;;
    u)
        USER_NAME=$OPTARG
        ;;
    d)
        DATABAG=$OPTARG
        ;;
    k)
        KEY_FILE=$OPTARG
        ;;
    i)
        INSTANCE=$OPTARG
        ;;
    x)
        SSH_USER_NAME=$OPTARG
        ;;
    a)
        SSH_HOST_ATTRIBUTE=$OPTARG
        ;;
    esac
done
shift $((OPTIND-1))

if [ -z "$VPN_SERVER_NODENAME" -o -z "$USER_NAME" -o -z "$DATABAG" -o -z "$KEY_FILE" ]; then
    echo "missing required parameters"
    show_help
    exit 1
fi

if [ -n "$INSTANCE" ]; then
  ITEM_NAME="${INSTANCE}_${USER_NAME}"
  KEYS_DIR="keys_${INSTANCE}"
else
  KEYS_DIR="keys"
fi

IP_ADDRESS=$(knife search node "name:${VPN_SERVER_NODENAME}" --format yaml -a $SSH_HOST_ATTRIBUTE 2>/dev/null |grep $SSH_HOST_ATTRIBUTE |cut -d: -f2 |tr -d ' ')

# Create the json file with user keys
knife ssh -a $SSH_HOST_ATTRIBUTE -x $SSH_USER_NAME "name:${VPN_SERVER_NODENAME}" "sudo echo -n '{
  \"id\": \"${ITEM_NAME}\",
  \"crt\": \"' > ${ITEM_NAME}.json; sudo cat /etc/openvpn/${KEYS_DIR}/${ITEM_NAME}.crt | perl -p -e 's/\\n/\\\n/' >> ${ITEM_NAME}.json; echo -n '\",
  \"csr\": \"' >> ${ITEM_NAME}.json; sudo cat /etc/openvpn/${KEYS_DIR}/${ITEM_NAME}.csr | perl -p -e 's/\\n/\\\n/' >> ${ITEM_NAME}.json; echo -n '\",
  \"key\": \"' >> ${ITEM_NAME}.json; sudo cat /etc/openvpn/${KEYS_DIR}/${ITEM_NAME}.key | perl -p -e 's/\\n/\\\n/' >> ${ITEM_NAME}.json; echo '\"
}' >> ${ITEM_NAME}.json"

# Pull that json file to the local machine
scp ${SSH_USER_NAME}@${IP_ADDRESS}:${ITEM_NAME}.json /tmp/${ITEM_NAME}.json

# Create the data bag item with 'knife data bag from file'
knife data bag from file $DATABAG /tmp/${ITEM_NAME}.json --secret-file ${KEY_FILE}

# Remove the data bag item on the remote vpn server
knife ssh -a $SSH_HOST_ATTRIBUTE -x $SSH_USER_NAME "name:${VPN_SERVER_NODENAME}" "rm ${ITEM_NAME}.json"

# Remove the data bag item file locally
rm /tmp/${ITEM_NAME}.json
