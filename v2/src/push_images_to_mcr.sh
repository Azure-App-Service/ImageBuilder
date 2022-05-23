#!/bin/bash
# --------------------------------------------------------------------------------------------
# This script pushes generated Docker Images to MCR
# Note: the script to build images be run prior to executing this script
# --------------------------------------------------------------------------------------------

set -e

declare -r SYSTEM_ARTIFACTS_DIR="$1"            # drop/ - when called from devops ; ../../output - when called from local
declare -r STACK_NAME=$2
declare -r BUILD_REASON=$3

declare -r LIST_OF_IMAGES_TO_PUSH_TO_MCR="${STACK_NAME}_LIST_OF_IMAGES_TO_PUSH_TO_MCR"

if [[ -z $STACK_NAME ]]; then
    echo "ERROR: Please specify stack name"
    exit
fi

if [[ -z $BUILD_REASON ]]; then
    echo "ERROR: Build Reason must be specified"
    exit
fi

while IFS= read -r image_name; do
    echo "Attempting to push image $image_name to MCR"

    # Push the generated images to MCR if the build reason is not pull request
    if [ "$BUILD_REASON" != "PullRequest" ]; then
        if [ ! -z $image_name ]; then
            docker push $image_name               
        fi
    else
        echo "ERROR: Unable to push images to MCR. (Build Reason : $BUILD_REASON)"
    fi

    echo

done < $SYSTEM_ARTIFACTS_DIR/$LIST_OF_IMAGES_TO_PUSH_TO_MCR