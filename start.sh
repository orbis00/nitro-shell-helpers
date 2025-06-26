#!/bin/bash
BRANCH_NAME=$1
FOLDER_PATH=$2
cd $FOLDER_PATH
git fetch --tags
git reset --hard $BRANCH_NAME
make build
make down
make up
