#!/bin/bash

source integration-testing.sh

check_and_make_lock /tmp/.lockfile
trap "cleanup_atexit /tmp/.lockfile" EXIT

sleep 20
echo "Test"
#test_urls_from_stdin "061SAH7M70/B067KSYMZJL/FQQPcSSAB5XrgvghpB25O5NJ" "https://getnitro.co" < post-deploy-urls.txt
