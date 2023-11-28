#!/bin/bash

source integration-testing.sh

make_singleton /tmp/.lockfile


#test_urls_from_stdin "061SAH7M70/B067KSYMZJL/FQQPcSSAB5XrgvghpB25O5NJ" "https://getnitro.co" < post-deploy-urls.txt

continue_script_if_new_version "orbis00/cdp-website.git" "refs/heads/main"

echo "here"
