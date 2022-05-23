#!/bin/bash

set -e

declare -r STACK="$1"
declare -r STAGE_NUMBER=$2
declare -r WAWS_IMAGE_REPO_NAME="wawsimages.azurecr.io"

function buildDockerImage() 
{
    if [[ $STAGE_NUMBER -gt 7 ]] || [[ $STAGE_NUMBER -lt 0 ]]; then
        exit 1
    fi

    local error="False"

    CurrentStage=0
    while [[ $CurrentStage -le $STAGE_NUMBER ]]; do
        CurrentTag="stage${CurrentStage}"
        if [[ $CurrentStage -eq 7 ]]; then
            CurrentTag="latest"
        fi
        CurrentImageTagUpperCase="${WAWS_IMAGE_REPO_NAME}/${STACK}:${CurrentTag}"
        CurrentImageTag="${CurrentImageTagUpperCase,,}"
        
        echo "Pulling Docker Image: $CurrentImageTag"
        docker pull $CurrentImageTag
        CurrentImageID=`docker images -q $CurrentImageTag`
        
        #match ImageIDs
        if [[ $CurrentStage != 0 ]] && [[ $CurrentImageID != $PreviousImageID ]]; then
            error="True"
        fi
        
        echo "Stage_$CurrentStage Docker Image ID = $CurrentImageID" 
        
        PreviousImageID=$CurrentImageID
        CurrentStage=$(($CurrentStage+1))
    done;

    #exit 1 if all previous stage tags are not similar.
    if [[ $error == "True" ]]; then
        exit 1
    fi
}

buildDockerImage
