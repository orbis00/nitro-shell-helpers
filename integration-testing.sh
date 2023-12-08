#!/bin/bash

cleanup_atexit() {
    rm -f "$1"
}

make_singleton() {
    if [ -f "$1" ]; then
        echo "Script is already running.."
        exit 1
    fi
    trap "cleanup_atexit $1" EXIT 
    touch "$1"
}

slack() {
   json="`jq -n --rawfile file $2 '{"text":$file}'`"
   curl -X POST -H 'Content-type: application/json' --data "$json" https://hooks.slack.com/services/$1
}

test_single_url() {
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

    echo "Starting Integration Test at $HOST" | tee -a /tmp/test_$RAND
    while read params; do
       test_single_url $params | tee -a /tmp/test_$RAND
    done
    echo "Integration Test Done for $HOST..." | tee -a /tmp/test_$RAND

    slack "$HOOK" /tmp/test_$RAND
    rm -f /tmp/test_$RAND
}

continue_script_if_new_version() {
    remote_version="`git ls-remote "git@github.com:$1" "$2" | cut -f 1 | xargs`"
    local_version="`git rev-parse HEAD`"

    echo "Remote: $remote_version vs Local: $local_version"
    if [ "$remote_version" = "$local_version" ]; then
        echo "Same remote version, nothing to deploy."
        exit 1
    fi
}

deploy() {
    truncate -s0 /tmp/$1
    echo "Deploying... in `pwd`" | tee -a /tmp/$1
    git pull 2>&1 | tee -a /tmp/$1
    make deploy 2>&1 | tee -a /tmp/$1_makeoutput
    result=$?
    if [ $result != 0 ]; then
        # some issue with Make - lets add to slack output.
        cat /tmp/$1_makeoutput >> /tmp/$1
    fi
    echo "Finished deploy: `date`" | tee -a /tmp/$1
}

