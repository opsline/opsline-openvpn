#!/usr/bin/env bash

set -xe

function show_help {
    echo ""
    echo "$(basename $0)"
    echo "  -h"
    echo "  -s <vpn server node name>"
    echo "  -d <databag name>"
    echo "  -k <encrypted data bag secret file>"
    echo "  [-i <vpn server instance name>]"
    echo "  [-x <ssh user name>]"
}

INSTANCE="default"
SSH_USER_NAME=$USER

while getopts "hs:d:k:i:x:" opt; do
    case "$opt" in
    h)
        show_help
        exit 0
        ;;
    s)
        VPN_SERVER_NODENAME=$OPTARG
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
    esac
done
shift $((OPTIND-1))

if [ -z "$VPN_SERVER_NODENAME" -o -z "$DATABAG" -o -z "$KEY_FILE" ]; then
    echo "missing required parameters"
    show_help
    exit 1
fi

if [ "$INSTANCE" == "default" ]; then
  KEYS_DIR="keys"
else
  KEYS_DIR="keys_${INSTANCE}"
fi

IP_ADDRESS=$(knife search node "name:${VPN_SERVER_NODENAME}" -a ipaddress 2>/dev/null |grep ipaddress |cut -d: -f2 |tr -d ' ')
DH_KEY_SIZE=$(knife node show ${VPN_SERVER_NODENAME} -a openvpn.key.size | grep key.size | awk '{print $2}')

# Create the json file with user keys
knife ssh -a ipaddress -x $SSH_USER_NAME "name:${VPN_SERVER_NODENAME}" "sudo echo -n '{
  \"id\": \"${INSTANCE}\",
  \"ca_crt\": \"' > ${INSTANCE}.json; sudo cat /etc/openvpn/${KEYS_DIR}/ca.crt | perl -p -e 's/\\n/\\\n/' >> ${INSTANCE}.json; echo -n '\",
  \"ca_key\": \"' >> ${INSTANCE}.json; sudo cat /etc/openvpn/${KEYS_DIR}/ca.key | perl -p -e 's/\\n/\\\n/' >> ${INSTANCE}.json; echo -n '\",
  \"dh\": \"' >> ${INSTANCE}.json; sudo cat /etc/openvpn/${KEYS_DIR}/dh${DH_KEY_SIZE}.pem | perl -p -e 's/\\n/\\\n/' >> ${INSTANCE}.json; echo -n '\",
  \"server_crt\": \"' >> ${INSTANCE}.json; sudo cat /etc/openvpn/${KEYS_DIR}/server.crt | perl -p -e 's/\\n/\\\n/' >> ${INSTANCE}.json; echo -n '\",
  \"server_csr\": \"' >> ${INSTANCE}.json; sudo cat /etc/openvpn/${KEYS_DIR}/server.csr | perl -p -e 's/\\n/\\\n/' >> ${INSTANCE}.json; echo -n '\",
  \"server_key\": \"' >> ${INSTANCE}.json; sudo cat /etc/openvpn/${KEYS_DIR}/server.key | perl -p -e 's/\\n/\\\n/' >> ${INSTANCE}.json; echo -n '\",
  \"tls_key\": \"' >> ${INSTANCE}.json; sudo cat /etc/openvpn/${KEYS_DIR}/ta.key | perl -p -e 's/\\n/\\\n/' >> ${INSTANCE}.json; echo '\"
}' >> ${INSTANCE}.json"

# Pull that json file to the local machine
scp ${SSH_USER_NAME}@${IP_ADDRESS}:${INSTANCE}.json /tmp/${INSTANCE}.json

# Create the data bag item with 'knife data bag from file'
#knife data bag from file $DATABAG /tmp/${INSTANCE}.json --secret-file ${KEY_FILE}

# Remove the data bag item on the remote vpn server
knife ssh -a ipaddress -x $SSH_USER_NAME "name:${VPN_SERVER_NODENAME}" "rm ${INSTANCE}.json"

# Remove the data bag item file locally
#rm /tmp/${INSTANCE}.json
