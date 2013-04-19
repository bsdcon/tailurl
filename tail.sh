#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage $0 <url to file>"
    exit 1
fi

BASE_URL=$(dirname $1)
FILE=$(basename $1)

FILE_LIST=$(lynx -dump -nolist -notitle "${BASE_URL}")
SIZE=$(echo "${FILE_LIST}"|sed -n -e "/$FILE/{n;p;}"|egrep -o "[0-9]+")

START_SIZE=$(expr $SIZE - 1000)

while [ true ]
do
    STATUS=$(curl -s -I --range $START_SIZE-$SIZE $1)
    STATUS_CODE=$(echo -e "${STATUS}"|egrep "HTTP/1.1 [0-9]+"|egrep -o "[0-9]{3}")
    CONTENT_LENGTH=$(echo -e "${STATUS}"|egrep "Content-Length: [0-9]+"|egrep -o "[0-9]+")
    if [ $STATUS_CODE == 206 ]; then
        DATA=$(curl -s --range $START_SIZE-$SIZE $1)
        echo -e "${DATA}"
        START_SIZE=$(expr $START_SIZE + $CONTENT_LENGTH)
        SIZE=$(expr $START_SIZE + 1000)
    fi
    sleep 1
done