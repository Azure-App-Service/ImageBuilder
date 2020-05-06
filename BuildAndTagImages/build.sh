#!/bin/bash
# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT license.
# This script builds Docker Images for all stacks on Azure App Service on Linux.
# --------------------------------------------------------------------------------------------

set -e


# Directory for Generated Docker Files
declare -r SYSTEM_ARTIFACTS_DIR="$1"
declare -r APP_SVC_BRANCH_PREFIX="$2"           # appsvc, appsvctest
declare -r CONFIG_DIR="$3"
declare -r PIPELINE_BUILD_NUMBER="$4"
declare -r STACK="$5"
declare -r BUILD_REASON="$6"
declare -r WAWS_IMAGE_REPO_NAME="wawsimages.azurecr.io"
declare -r ACR_BUILD_IMAGES_ARTIFACTS_FILE="$SYSTEM_ARTIFACTS_DIR/builtImages.txt"

function buildDockerImage() 
{
    if [ -f "$CONFIG_DIR/${STACK}VersionTemplateMap.txt" ]; then
        while IFS=, read -r STACK_VERSION BASE_IMAGE STACK_VERSION_TEMPLATE_DIR STACK_TAGS || [[ -n $STACK_VERSION ]] || [[ -n $BASE_IMAGE ]] || [[ -n $STACK_VERSION_TEMPLATE_DIR ]] || [[ -n $STACK_TAGS ]]
        do
            echo "Stack Tag is ${STACK_TAGS}"
            IFS='|' read -ra STACK_TAGS_ARR <<< "$STACK_TAGS"
            for TAG in "${STACK_TAGS_ARR[@]}"
            do
                if [[ $STACK = "php-xdebug" ]]
                then
                    STACK="php"
                fi 
		# Build Image Tags are converted to lower case because docker doesn't accept upper case tags
                local MCRRepoTagUpperCase="${WAWS_IMAGE_REPO_NAME}/public/appsvc/${STACK}:${TAG}_${PIPELINE_BUILD_NUMBER}"
                local MCRRepoTag="${MCRRepoTagUpperCase,,}"
                local appSvcDockerfilePath="${SYSTEM_ARTIFACTS_DIR}/${STACK}/GitRepo/${STACK_VERSION}/Dockerfile" 
                local BuildVerRepoTagUpperCase="${WAWS_IMAGE_REPO_NAME}/${STACK}:${TAG}_${PIPELINE_BUILD_NUMBER}"
                local BuildVerRepoTag="${BuildVerRepoTagUpperCase,,}"

                echo "Listing artifacts dir"
                ls "${SYSTEM_ARTIFACTS_DIR}"
                echo "Listing stacks dir"
                ls "${SYSTEM_ARTIFACTS_DIR}/${STACK}/GitRepo/${STACK_VERSION}"
                cd "${SYSTEM_ARTIFACTS_DIR}/${STACK}/GitRepo/${STACK_VERSION}"

                echo
                echo "Building test image with tag '$BuildVerRepoTag' and file $appSvcDockerfilePath..."

                # php-xdebug depends of published images
                if [ "$BUILD_REASON" != "PullRequest" ] || ["$STACK" != "php-xdebug" ]; then
                    echo docker build -t "$BuildVerRepoTag" -f "$appSvcDockerfilePath" .
                    docker build -t "$BuildVerRepoTag" -f "$appSvcDockerfilePath" .
                elif [ "$BUILD_REASON" != "PullRequest" ] && ["$STACK" == "php-xdebug" ]; then
                    # poll until php image is published
                    BASE_TAG=`head -n 1 Dockerfile | sed 's/FROM //g'`
                    PULL_OUTPUT=`docker pull $BASE_TAG`
                    LOOP_COUNTER=0;
                    while [[ $PULL_OUTPUT != *"up to date"* ]] && [ $LOOP_COUNTER -le 60 ]; do
                        sleep 1m
                        PULL_OUTPUT=$(docker pull $BASE_TAG)
                        LOOP_COUNTER=$LOOP_COUNTER+1
                    done;
                    echo docker build -t "$BuildVerRepoTag" -f "$appSvcDockerfilePath" .
                    docker build -t "$BuildVerRepoTag" -f "$appSvcDockerfilePath" .
                fi

                if [ "$BUILD_REASON" != "PullRequest" ]; then
                    docker push $BuildVerRepoTag
                    docker tag $BuildVerRepoTag $MCRRepoTag
                    docker push $MCRRepoTag
                fi

                echo $MCRRepoTag >> $SYSTEM_ARTIFACTS_DIR/${STACK}builtImageList
            done
        done < "$CONFIG_DIR/${STACK}VersionTemplateMap.txt"
    else
        # KuduLite Image, add single image support
        local BuildVerRepoTagUpperCase="${WAWS_IMAGE_REPO_NAME}/${STACK}:${PIPELINE_BUILD_NUMBER}"
        local BuildVerRepoTag="${BuildVerRepoTagUpperCase,,}"
        local MCRRepoTagUpperCase="${WAWS_IMAGE_REPO_NAME}/public/appsvc/${STACK}:${PIPELINE_BUILD_NUMBER}"
        local MCRRepoTag="${MCRRepoTagUpperCase,,}"
        local appSvcDockerfilePath="${SYSTEM_ARTIFACTS_DIR}/${STACK}/GitRepo/kudu/Dockerfile"

        echo "Listing artifacts dir"
        ls "${SYSTEM_ARTIFACTS_DIR}"
        echo "Listing stacks dir"
        ls "${SYSTEM_ARTIFACTS_DIR}/${STACK}/GitRepo/kudu"
        cd "${SYSTEM_ARTIFACTS_DIR}/${STACK}/GitRepo/kudu"
        echo
        echo "Building test image with tag '$BuildVerRepoTag' and file $appSvcDockerfilePath..."
        echo docker build -t "$BuildVerRepoTag" -f "$appSvcDockerfilePath" .
        docker build -t "$BuildVerRepoTag" -f "$appSvcDockerfilePath" .
        docker tag $BuildVerRepoTag $MCRRepoTag

        # only push the images if merging to the master
        if [ "$BUILD_REASON" != "PullRequest" ]; then
            docker push $BuildVerRepoTag
            docker push $MCRRepoTag
        fi

        echo $MCRRepoTag >> $SYSTEM_ARTIFACTS_DIR/${STACK}builtImageList
    fi
}

buildDockerImage
