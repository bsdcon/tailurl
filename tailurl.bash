#!/bin/bash

#
# Original: https://gist.github.com/habibutsu/5420781
# Modified by Adrian Penisoara  << ady+tailurl (at) bsdconsultants.com >>
#

usage() {
    echo "Usage: $0 [ -u <username> ] <url to monitor>"
    exit 1
}

while getopts ":u:" arg; do
  case $arg in
     u) user=$OPTARG
        stty -echo
        # Prompt on STDERR to avoid interfering/masking with piping
        echo -n "Password for user $user: " >&2
        read pass
        stty echo
        CURL_FLAGS="-u $user:$pass"
        ;;

     *) echo "Syntax error"
        usage
        ;;
  esac
done
shift $((OPTIND-1))

if [ -z "$1" ]; then
   usage
fi

URL="$1"
CURL_CMD="curl --url $URL -s $CURL_FLAGS"

STATUS=$($CURL_CMD -I)
SIZE=$(echo -e "${STATUS}"|egrep "Content-Length: [0-9]+"|egrep -o "[0-9]+")

START_SIZE=$(expr $SIZE - 1000)
if [ $START_SIZE -lt 0 ]; then
    START_SIZE=0
fi

while [ true ]
do
    STATUS=$($CURL_CMD -I --range $START_SIZE-)
    STATUS_CODE=$(echo -e "${STATUS}"|egrep "HTTP/1.1 [0-9]+"|egrep -o "[0-9]{3}")
    CONTENT_LENGTH=$(echo -e "${STATUS}"|egrep "Content-Length: [0-9]+"|egrep -o "[0-9]+")
    if [ $STATUS_CODE == 206 ]; then
        SIZE=$(expr $START_SIZE + $CONTENT_LENGTH)
        $CURL_CMD --range $START_SIZE-$SIZE
        START_SIZE=$(expr $START_SIZE + $CONTENT_LENGTH)
    fi
    sleep 1
done