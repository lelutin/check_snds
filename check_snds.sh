#!/bin/bash

#####
#
# Monitoring plugin to check, if a given IP address is blacklisted or has bad
# reputation (colour-coded) in SNDS.
#
# Copyright (c) 2017 Jan Vonde <mail@jan-von.de>
# Copyright (c) 2019 Kienan Stewart <kienan@koumbit.org>
#
#
# Usage: ./check_snds.sh -i 1.2.3.4 -k aaa-bbb-ccc-111-222-333
#
# 
# For more information visit https://github.com/janvonde/check_snds
#####


USAGE="Usage: check_snds.sh -i [IP] -k [KEY]"

if [ $# -ge 4 ]; then
	while getopts "i:k:"  OPCOES; do
		case $OPCOES in
			i ) IP=$OPTARG;;
			k ) KEY=$OPTARG;;
			* ) echo "$USAGE"
			     exit 1;;
		esac
	done
else 
	echo "$USAGE"; exit 3
fi


## check if needed programs are installed
type -P curl &>/dev/null || { echo "ERROR: curl is required but seems not to be installed.  Aborting." >&2; exit 1; }
type -P sed &>/dev/null || { echo "ERROR: sed is required but seems not to be installed.  Aborting." >&2; exit 1; }


## get ipStatus from SNDS
SNDSFILE=$(curl -s https://sendersupport.olc.protection.outlook.com/snds/ipStatus.aspx?key="${KEY}")

## check if IP is included in SNDSFILE
if [[ ${SNDSFILE} =~ .*$IP.* ]]; then
	CAUSE=$(echo "${SNDSFILE}" | grep "${IP}" | cut -d, -f4)
	echo "ERROR: IP ${IP} is blacklisted +++ ${CAUSE} | blacklist=1"
	exit 2
fi


## check reputation color reported by SNDS data
SNDS_DATA_FILE=$(curl -s https://sendersupport.olc.protection.outlook.com/snds/data.aspx?key="${KEY}" | grep "$IP")
if [[ -n "$SNDS_DATA_FILE" ]]; then
    COLOUR=$(echo "$SNDS_DATA_FILE" | cut -d ',' -f 7)
    COMPLAINT_RATE=$(echo "$SNDS_DATA_FILE" | cut -d ',' -f 8)
    PERIOD=$(echo "$SNDS_DATA_FILE" | cut -d ',' -f 2,3)
    STATS=$(echo "$SNDS_DATA_FILE" | cut -d ',' -f 4,5,6)
    case "$COLOUR" in
        "GREEN")
            echo "OK: IP ${IP} is not blacklisted and reputation is ${COLOUR} in period ${PERIOD} | blacklist=0,complaint_rate=${COMPLAINT_RATE},stats=${STATS}"
        ;;
        "YELLOW")
            echo "WARNING: IP ${IP} is not blacklisted but reputation is ${COLOUR} in period ${PERIOD} | blacklist=0,complaint_rate=${COMPLAINT_RATE},stats=${STATS}"
            exit 1
        ;;
        "RED")
            echo "ERROR: IP ${IP} is not blacklisted but reputation is ${COLOUR} in period ${PERIOD} | blacklist=0,complaint_rate=${COMPLAINT_RATE},stats=${STATS}"
            exit 2
            ;;
        "*")
            echo "UNKNOWN: unknown reputation result ${COLOUR} for IP ${IP}"
            exit 3
    esac
else
    echo "UNKNOWN: IP ${IP} is not listed in SNDS data"
    exit 3
fi
