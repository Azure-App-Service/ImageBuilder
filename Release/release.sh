#!/bin/bash
# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT license.
# This script publishes the runtime and the build images to Microsoft Container Registry 
# for Azure App Services on Linux
# --------------------------------------------------------------------------------------------

set -e

# Set BUILD to the images' build number you wish to push to APP_SVC_MCR_REPO
# TODO: Move to Params
declare -r BUILD="20191114.1"

declare -r DEFAULT_WORKING_DIRECTORY="$1" # $(System.DefaultWorkingDirectory)
declare -r APP_SVC_MCR_REPO="wawsimages.azurecr.io"
declare -r APP_SVC_DEV_ACR="appsvcdevacr.azurecr.io"

function tagACRImagesToDockerHub()
{
    echo "Tagging test acr images and pushing them to MCR"
    echo "Build number is $BUILD"

    while IFS=, read -r STACK ||  [[ -n $STACK ]]
	do
        echo "Processing $STACK tags"
        while IFS=, read -r TAG ||  [[ -n $TAG ]]
        do
            if [[ $TAG == *$BUILD ]]
            then
                # Tag images from APP_SVC_DEV_ACR to APP_SVC_MCR_REPO
                local imageName="${STACK}:${TAG}"
                local acrImage="${APP_SVC_DEV_ACR}/${imageName}"
                local mcrImage="${APP_SVC_MCR_REPO}/public/${imageName}"
                echo "Pulling from test acr. Image: $acrImage"
                docker pull ${acrImage}
                echo "Tagging image test image to prod ACR"
                docker tag ${acrImage} ${mcrImage}
                echo "Pushing image $mcrImage"
                docker push ${mcrImage}
            fi
        done < "$DEFAULT_WORKING_DIRECTORY/tags/$STACK"
    done < "$DEFAULT_WORKING_DIRECTORY/tags_list"
}

tagACRImagesToDockerHub
