#!/bin/bash

source <(curl -s https://raw.githubusercontent.com/orbis00/nitro-shell-helpers/main/integration-testing.sh?_=$RANDOM)
make_singleton /tmp/.httpwatch.lock

FOR="httpwatcher"
truncate -s0 /tmp/$FOR
date

URLS=("https://t.makehook.ws/amazin-spiderman" \
      "https://svc.nitrocommerce.ai/" \
      "https://x.nitrocommerce.ai/" \
      "https://kb.getnitro.co/" \
      "https://nitrocommerce.ai/" \
      "https://ray.makehook.ws" \
      "https://testplan.nitrocommerce.ai/accounts/login/?next=/" \
      "https://docs.nitrocommerce.ai/" \
      "https://sso.nitrocommerce.ai/" \
)

for url in ${URLS[@]}; do
    echo "Scanning.. $url"
    res="`curl --write-out '%{http_code}' --silent --output /dev/null \"$url\"`"

    if [ "$res" = "200" ]; then
        echo "Reachable Host: $url" 
    else
        echo "WARNING: Unreachable host: $res - $url" | tee -a /tmp/$FOR
    fi
    
done

if [ -s /tmp/$FOR ]; then
    slack "T061SAH7M70/B067MSYJ5PW/WSJ7WYVaDBw3BoyQmSBON1aq" /tmp/$FOR
fi

echo "-----------------------------------------------"
