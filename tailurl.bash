#!/bin/bash

#
# Source:   https://gist.github.com/bsdcon/7224196
# Original: https://gist.github.com/habibutsu/5420781
# Modified by Adrian Penisoara  << ady+tailurl (at) bsdconsultants.com >>
#

usage() {
    echo "Usage: $0 [ -u <username> [ -p <password> ]] [-{f|F} [-s <sleep interval> ] [ -t <interval> ]] <url to monitor>"
    exit 1
}

curl_error() {
    if [ "$1" -ne 0 ]; then
        echo "CURL exited with error code $1 -- aborting" >&2
        exit $2
    fi
}

http_error() {
    cat >&2 <<EOF

HTTP ERROR: $1

EOF
    [ -n "$2" ] && cat >&2 <<EOF
- - - - - - - - - - - - - - - - -
$2
EOF
    exit 2
}

[ -n "$TAILURL_USER" ] && user="$TAILURL_USER"
[ -n "$TAILURL_PASSWORD" ] && pass="$TAILURL_PASSWORD"

follow=NO
retry=NO
sleep=${TAILURL_SLEEP:-1}
while getopts ":fFu:p:s:t:" arg; do
  case $arg in
     f) follow=YES
        ;;

     F) follow=YES
        retry=YES
        ;;

     u) user=$OPTARG
        ;;

     p) if [ -z "$user" ]; then
            echo "Error: password argument requires user being set"
            usage
        fi
        pass=$OPTARG
        ;;

     s) sleep=$OPTARG
        ;;

     t) tstamp=$OPTARG
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

if [ -n "$user" ]; then
    if [ -z "$pass" ]; then
        # Prompt on STDERR to avoid interfering/masking with piping
        echo -n "Password for user $user: " >&2
        stty -echo
        read pass
        stty echo
    fi
    CURL_FLAGS="-u $user:$pass"
fi

CURL_CMD="curl --url $URL -s $CURL_FLAGS"

STATUS=$($CURL_CMD -I) || curl_error $?
STATUS_CODE=$(echo -e "${STATUS}"|egrep "HTTP/1.1 [0-9]+"|egrep -o "[0-9]{3}")
SIZE=$(echo -e "${STATUS}"|egrep "Content-Length: [0-9]+"|egrep -o "[0-9]+")

if [ "${STATUS_CODE:0:1}xx" != "2xx" ]; then
    http_error "Resource unreachable or does not support HTTP 1.1" "$STATUS"
fi

if [ -z "$SIZE" ]; then
    http_error "Resource does not support size inquiry" "$STATUS"
fi

START_SIZE=$(expr $SIZE - 1000)
if [ $START_SIZE -lt 0 ]; then
    START_SIZE=0
fi

# idle cycles counter
icounter=0
while [ true ]
do
    STATUS=$($CURL_CMD -I --range $START_SIZE-) || curl_error $?
    STATUS_CODE=$(echo -e "${STATUS}"|egrep "HTTP/1.1 [0-9]+"|egrep -o "[0-9]{3}")
    CONTENT_LENGTH=$(echo -e "${STATUS}"|egrep "Content-Length: [0-9]+"|egrep -o "[0-9]+")
    if [ $STATUS_CODE == 206 ]; then
        SIZE=$(expr $START_SIZE + $CONTENT_LENGTH)
        $CURL_CMD --range $START_SIZE-$SIZE || curl_error $?
        START_SIZE=$SIZE
        icounter=0
    elif [ "${STATUS_CODE:0:3}" = "416" ]; then
        if [ $retry = YES ]; then
            STATUS=$($CURL_CMD -I) || curl_error $?
            newsize=$(echo -e "${STATUS}"|egrep "Content-Length: [0-9]+"|egrep -o "[0-9]+")
            if [ $newsize -lt $SIZE ]; then
                echo "==> File has been truncated -- restarting from 0" >&2
                START_SIZE=0
                continue
            fi
        fi
    else
        http_error "Resource no longer reachable" "$STATUS"
    fi
    [ $follow = YES ] || break

    if [ -n "$tstamp" -a $icounter -ge $tstamp ]; then
        printf "\n[ $(date) ]\n\n" >&2
        # Disable counter until next update
        icounter=-1
    fi

    sleep $sleep
    [ $icounter -ge 0 ] && icounter=$(expr $icounter + 1)
done