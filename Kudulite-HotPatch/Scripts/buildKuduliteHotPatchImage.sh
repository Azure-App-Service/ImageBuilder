#!/bin/bash
# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT license.
# This script builds Kudulite Hot Patch stretch and buster based images
# --------------------------------------------------------------------------------------------

set -e


# Directory for Generated Docker Files
declare -r SYSTEM_ARTIFACTS_DIR="$1"
declare -r APP_SVC_BRANCH_PREFIX="$2"           # appsvc, appsvctest
declare -r CONFIG_DIR="$3"
declare -r PIPELINE_BUILD_NUMBER="$4"
declare -r STACK="$5"
declare -r BUILD_REASON="$6"
declare -r FILES_ROOT_PATH="$7"
declare -r IMG_TAG="$8"
declare -r WAWS_IMAGE_REPO_NAME="wawsimages.azurecr.io"
declare -r ACR_BUILD_IMAGES_ARTIFACTS_FILE="$SYSTEM_ARTIFACTS_DIR/builtImages.txt"

function displayArtifactsDir()
{
    local artifactsDir=$1
    echo "Listing artifacts dir :"
    echo "--------------------------"
    ls $artifactsDir
    echo 
}

function displayInformationRegardingImageToBeBuilt()
{
    local tag=$1
    local dockerFilePath=$2
    echo "Building test image with "
    echo "--------------------------"
    echo "Tag           : $BuildVerRepoTag "
    echo "DockerFile    : $appSvcDockerfilePath"
    echo
}

function buildDockerImage() 
{    
    # KuduLite Image, add single image support

    local BuildVerRepoTagUpperCase="${WAWS_IMAGE_REPO_NAME}/${STACK}:${IMG_TAG}"
    local BuildVerRepoTag="${BuildVerRepoTagUpperCase,,}"
    local MCRRepoTagUpperCase="${WAWS_IMAGE_REPO_NAME}/public/appsvc/${STACK}:${IMG_TAG}"
    local MCRRepoTag="${MCRRepoTagUpperCase,,}"
    local appSvcDockerfilePath="${SYSTEM_ARTIFACTS_DIR}/${STACK}/${FILES_ROOT_PATH}/Dockerfile"

    displayArtifactsDir "${SYSTEM_ARTIFACTS_DIR}"
    cd "${SYSTEM_ARTIFACTS_DIR}/${STACK}/${FILES_ROOT_PATH}"
    displayInformationRegardingImageToBeBuilt $BuildVerRepoTag $appSvcDockerfilePath
    echo docker build -t "$BuildVerRepoTag" -f "$appSvcDockerfilePath" .
    docker build -t "$BuildVerRepoTag" -f "$appSvcDockerfilePath" .
    docker tag $BuildVerRepoTag $MCRRepoTag

    # only push the images if merging to the master
    if [ "$BUILD_REASON" != "PullRequest" ]; then
        docker push $BuildVerRepoTag
        docker push $MCRRepoTag
    fi

    echo $MCRRepoTag >> $SYSTEM_ARTIFACTS_DIR/${STACK}builtImageList

}

buildDockerImage
