#!/bin/bash

# Variables
BASE_DIR="$(realpath $(dirname ${BASH_SOURCE[0]}))"
RELEASE_TAG=${RELEASE_TAG:-$1}
RELEASE_MAIN_BRANCH=${RELEASE_MAIN_BRANCH:-'main'}
RELEASE_ORIGIN=${RELEASE_ORIGIN:-'origin'}
RELEASE_BRANCH="release-${RELEASE_TAG%.*}.x"

apply_sed() {
    SHORT_UNAME=$(uname -s)
    if [ "$(uname)" == "Darwin" ]; then
        sed -i '' "$1" "$2"
    elif [ "${SHORT_UNAME:0:5}" == "Linux" ]; then
        sed -i "$1" "$2"
    fi
}

resetChanges() {
    local origin=${2:-'origin'}

    echo "[INFO] Reset changes in $1 branch"
    git reset --hard
    git checkout $1
    git fetch $origin --prune
    git pull $origin $1
}

checkoutToReleaseBranch() {
    echo "[INFO] Checking out to $RELEASE_BRANCH branch."
    if git ls-remote -q --heads | grep -q $RELEASE_BRANCH ; then
        echo "[INFO] $RELEASE_BRANCH exists."
        resetChanges $RELEASE_BRANCH
    else
        echo "[INFO] $RELEASE_BRANCH does not exist. Will create a new one from main."
        resetChanges main
        git push $RELEASE_ORIGIN main:$RELEASE_BRANCH
    fi
    git checkout -B $RELEASE_TAG
}

commitChanges() {
    echo "[INFO] Pushing changes to $RELEASE_TAG branch"
    git add -A
    git commit -s -m "$1"
    git push origin $RELEASE_TAG
}

createReleaseBranch() {
    echo "[INFO] Create the release branch based on $RELEASE_TAG"
    git push origin $RELEASE_TAG
}

createPR() {
    echo "[INFO] Creating a PR"
    hub pull-request --base ${RELEASE_BRANCH} --head ${RELEASE_TAG} -m "$1"
}

bumpVersion() {
    IFS='.' read -a semver <<< "$RELEASE_TAG"
    MAJOR=${semver[0]}
    MINOR=${semver[1]}
    RELEASE_TAG=$MAJOR.$((MINOR+1)).0
}

compareMainVersion() {
    # Parse the version passed in.
    IFS='.' read -a semver <<< "${RELEASE_TAG}"
    MAJOR=${semver[0]}
    MINOR=${semver[1]}
    BUGFIX=${semver[2]}
    
    # Compare the new vers
    if ((latestMajor <= MAJOR)) && ((latestMinor <= MINOR)) && ((latestBugfix <= BUGFIX)); then
        return 0
    else
        return 1
    fi
}

processReleaseChanges() {
    echo "[INFO] Processing release changes"
    yq ".version = ${RELEASE_TAG}" $BASE_DIR/chart/Chart.yaml
    if [ $? -ne 0 ]; then
        echo "Processing release changes: FAILED"
        exit 1
    fi
}

if ! command -v hub > /dev/null; then
  echo "[ERROR] The hub CLI needs to be installed. See https://github.com/github/hub/releases"
  exit
fi
if [[ -z "${GITHUB_TOKEN}" ]]; then
  echo "[ERROR] The GITHUB_TOKEN environment variable must be set."
  exit
fi

echo "[INFO] Releasing a new ${RELEASE_TAG} version"

if [[ $(git branch --show-current) != "${RELEASE_MAIN_BRANCH}" ]]; then
    USER_INPUT=''
    until [[ $USER_INPUT == 'y' ]] || [[ $USER_INPUT == 'n' ]]; do
        read -p "WARNING: you are not under the repository main branch '${RELEASE_MAIN_BRANCH}', do you wish to continue? (y/n): " USER_INPUT
        if [[ $USER_INPUT != 'y' ]] && [[ $USER_INPUT != 'n' ]]; then
            echo "Answer must be y/n."
        fi
    done
    
    if [[ $USER_INPUT == 'n' ]]; then
        exit 0
    fi
fi

checkoutToReleaseBranch

processReleaseChanges

commitChanges "chore(release): ${RELEASE_TAG}"

createReleaseBranch

createPR "Release version ${RELEASE_TAG}"
