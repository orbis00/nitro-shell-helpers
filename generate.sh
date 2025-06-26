#!/bin/bash

echo "Generating tag..."
GITHUB_USER=$(git config user.name)

if [ -z "${GITHUB_USER}" ]; then
    echo "GitHub username not set in git config. Please set it using 'git config user.name <your-username>'."
    exit 1
fi
GITHUB_USER=$(echo "${GITHUB_USER}" | tr ' ' '_')
echo "GitHub user: ${GITHUB_USER}"
DATE=$(date +%Y-%m-%d)
PREFIX="stage-${GITHUB_USER}-${DATE}-"
LATEST_TAG=$(git tag -l "${PREFIX}*" | sort -V | tail -n 1)

# Extract the number from the latest tag and increment it
if [ -z "${LATEST_TAG}" ]; then
    NEW_TAG="${PREFIX}01"
else
    LATEST_NUMBER=$(echo "${LATEST_TAG}" | sed -e "s/^${PREFIX}//")
    # Ensure the latest number is a valid integer
    if ! [[ "${LATEST_NUMBER}" =~ ^[0-9]+$ ]]; then
        echo "Error: Tag number is not valid. Latest tag: ${LATEST_TAG}"
        exit 1
    fi
    NEW_NUMBER=$((10#${LATEST_NUMBER} + 1))
    # Format the new number to two digits with leading zero
    NEW_TAG="${PREFIX}$(printf "%02d" ${NEW_NUMBER})"
fi

# Prompt for a commit hash and default to the latest commit in the 'stage' branch
read -p "Enter the commit hash to tag (leave empty for the latest commit in 'stage' branch): " COMMIT_HASH

if [ -z "${COMMIT_HASH}" ]; then
    COMMIT_HASH="HEAD"
fi

if ! git cat-file -e "${COMMIT_HASH}^{commit}" 2>/dev/null; then
    echo "Error: Invalid commit hash."
    exit 1
fi

echo "Creating tag ${NEW_TAG} on commit ${COMMIT_HASH}"

git tag "${NEW_TAG}" "${COMMIT_HASH}"
git push origin "${NEW_TAG}"
