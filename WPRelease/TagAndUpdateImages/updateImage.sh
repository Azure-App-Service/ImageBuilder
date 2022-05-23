#!/bin/bash

set -e

declare -r STACK="$1"
declare -r STAGE_NUMBER=$2
declare -r BUILD_REASON="$3"
declare -r BASE_IMAGE_TAG="${BASE_IMAGE_TAG:="test"}"
declare -r WAWS_IMAGE_REPO_NAME="wawsimages.azurecr.io"

function pullDockerImage()
{
    PULL_OUTPUT=`docker pull $1`
    LOOP_COUNTER=0;
    while [[ $PULL_OUTPUT != *"up to date"* ]] && [ $LOOP_COUNTER -le 60 ]; do
        sleep 30s
        PULL_OUTPUT=$(docker pull $1)
        LOOP_COUNTER=$LOOP_COUNTER+1
    done;
}

function buildDockerImage() 
{
    if [[ $STAGE_NUMBER -gt 7 ]] || [[ $STAGE_NUMBER -lt 0 ]]; then
        exit 1
    fi

    local TAG="stage${STAGE_NUMBER}"
    if [ $STAGE_NUMBER -eq 7 ]; then
        TAG="latest"
    fi

    # Build Image Tags are converted to lower case because docker doesn't accept upper case tags
    local MCRTagUpperCase="${WAWS_IMAGE_REPO_NAME}/public/appsvc/${STACK}:${TAG}"
    local MCRTag="${MCRTagUpperCase,,}"
    local BuildVerRepoTagUpperCase="${WAWS_IMAGE_REPO_NAME}/${STACK}:${TAG}"
    local BuildVerRepoTag="${BuildVerRepoTagUpperCase,,}"

    #Stage Images are tagged to the previous stage image.
    #Stage 0 is tagged to "test" tag by default unless BASE_IMAGE_TAG variable in pipeline is changed
    local PreviousStageTag=$BASE_IMAGE_TAG
    if [ $STAGE_NUMBER -ge 1 ]; then
        local PreviousStageNumber=$(($STAGE_NUMBER-1))
        PreviousStageTag="stage${PreviousStageNumber}"
    fi

    local PreviousImageTagUpperCase="${WAWS_IMAGE_REPO_NAME}/${STACK}:${PreviousStageTag}"
    local PreviousImageTag="${PreviousImageTagUpperCase,,}"               

    #Pull previous stage image.
    pullDockerImage $PreviousImageTag
    

    if [ "$BUILD_REASON" != "PullRequest" ]; then
        docker tag $PreviousImageTag $BuildVerRepoTag
        docker push $BuildVerRepoTag
        docker tag $PreviousImageTag $MCRTag
        docker push $MCRTag
    fi
}

buildDockerImage
