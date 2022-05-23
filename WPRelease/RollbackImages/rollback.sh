#!/bin/bash

set -e

declare -r STACK="$1"
declare -r STAGE_NUMBER=$2
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
    if [ $STAGE_NUMBER -gt 6 ] || [ $STAGE_NUMBER -lt 0 ]; then
        exit 1
    fi

    #Pull latest tag
    local LatestImageTagUpperCase="${WAWS_IMAGE_REPO_NAME}/appsvc/${STACK}:latest"
    local LatestImageTag="${LatestImageTagUpperCase,,}"
    pullDockerImage $LatestImageTag

    #Rollback previous stages to latest tag
    CurrentStage=0
    while [[ $CurrentStage -le $STAGE_NUMBER ]]; do        
        local TAG="stage${CurrentStage}"
        
        # Build Image Tags are converted to lower case because docker doesn't accept upper case tags
        local MCRTagUpperCase="${WAWS_IMAGE_REPO_NAME}/public/appsvc/${STACK}:${TAG}"
        local MCRTag="${MCRTagUpperCase,,}"
        local BuildVerRepoTagUpperCase="${WAWS_IMAGE_REPO_NAME}/${STACK}:${TAG}"
        local BuildVerRepoTag="${BuildVerRepoTagUpperCase,,}"
        
        if [ "$BUILD_REASON" != "PullRequest" ]; then
            docker tag $latestImageTag $BuildVerRepoTag
            docker push $BuildVerRepoTag
            docker tag $latestImageTag $MCRTag
            docker push $MCRTag
        fi    
        
        CurrentStage=$(($CurrentStage+1))
    done;
}

buildDockerImage
