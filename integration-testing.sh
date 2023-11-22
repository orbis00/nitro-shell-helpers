#!/bin/bash

slack() {
   json="`jq -n --rawfile file $1 '{"text":$file}'`"
   curl -X POST -H 'Content-type: application/json' --data "$json" https://hooks.slack.com/services/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
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
    HOST="https://getnitro.co"
    RAND=$RANDOM
    truncate -s0 /tmp/test_$RAND

    echo "Starting Integration Test..."
    while read params; do
       echo "Testing $params"
       test_url $params >> /tmp/test_$RAND
    done

    slack /tmp/test_$RAND
    rm -f /tmp/test_$RAND
}
