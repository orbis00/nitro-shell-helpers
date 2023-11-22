#!/bin/bash

slack() {
   json="`jq -n --rawfile file $2 '{"text":$file}'`"
   curl -X POST -H 'Content-type: application/json' --data "$json" https://hooks.slack.com/services/$1
}

test_url() {
   resp_code=$(curl -s -o /dev/null -w "%{http_code}" "$HOST$2")
   if [ "$resp_code" = "$1" ]; then
       echo "Passed $HOST$2 (Got: $resp_code)"
   else
       echo "Failed $HOST$2 (Got: $resp_code)"
   fi
}


test_urls_from_stdin() {
    HOOK="$1"
    HOST="$2"
    RAND=$RANDOM
    truncate -s0 /tmp/test_$RAND

    echo "Starting Integration Test at $HOST / `date`" | tee /tmp/test_$RAND
    while read params; do
       test_url $params | tee /tmp/test_$RAND
    done
    echo "Integration Test Done for $HOST..." | tee /tmp/test_$RAND

    slack "$HOOK" /tmp/test_$RAND
    rm -f /tmp/test_$RAND
}
