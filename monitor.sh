#!/bin/bash

source <(curl -s https://raw.githubusercontent.com/orbis00/nitro-shell-helpers/main/integration-testing.sh?_=$RANDOM)


make_singleton /tmp/.nmapping.lock
FOR="nmaping"
truncate -s0 /tmp/$FOR

HOSTS=(34.131.58.144 34.131.11.11)

for h in ${HOSTS[@]}; do
    echo "Scanning.. $h"
    nmap -Pn $h 2>&1 > /tmp/scan-details.log
    cat /tmp/scan-details.log | grep -v '^22/tcp' | grep -v '^22/tcp' | grep -v 'closed' |grep -P '^\d+\/(tcp|udp).+'
    res="$?"
    if [ "$res" = 0 ]; then
        echo "Security issue for $h!" >> /tmp/$FOR
	cat /tmp/scan-details.log | grep -v '^22/tcp' | grep -v '^22/tcp' | grep -v 'closed' |grep -P '^\d+\/(tcp|udp).+' >> /tmp/$FOR
    else
        echo "No Security Leak for $h - We are good!" >> /tmp/$FOR
    fi
    echo "------------------------------------------------------------" >> /tmp/$FOR
done

slack "T061SAH7M70/B067MSYJ5PW/WSJ7WYVaDBw3BoyQmSBON1aq" /tmp/$FOR
