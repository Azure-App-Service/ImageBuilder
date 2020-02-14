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
declare -r TEST_IMAGE_REPO_NAME="appsvcdevacr.azurecr.io"
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
                # Build Image Tags are converted to lower case because docker doesn't accept upper case tags
                local TestRepoTagUpperCase="${TEST_IMAGE_REPO_NAME}/${STACK}:${TAG}_${PIPELINE_BUILD_NUMBER}"
                local TestRepoTag="${TestRepoTagUpperCase,,}"
                local appSvcDockerfilePath="${SYSTEM_ARTIFACTS_DIR}/${STACK}/GitRepo/${STACK_VERSION}/Dockerfile" 
                
		echo "Listing artifacts dir"
                ls "${SYSTEM_ARTIFACTS_DIR}"
                echo "Listing stacks dir"
                ls "${SYSTEM_ARTIFACTS_DIR}/${STACK}/GitRepo/${STACK_VERSION}"
                cd "${SYSTEM_ARTIFACTS_DIR}/${STACK}/GitRepo/${STACK_VERSION}"

                echo
                echo "Building test image with tag '$TestRepoTag' and file $appSvcDockerfilePath..."
                echo docker build -t "$TestRepoTag" -f "$appSvcDockerfilePath" .
                docker build -t "$TestRepoTag" -f "$appSvcDockerfilePath" .

                if [ "$BUILD_REASON" != "PullRequest" ]; then
                    docker push $TestRepoTag
                fi

                echo $TestRepoTag > $SYSTEM_ARTIFACTS_DIR/builtImageList
            done
        done < "$CONFIG_DIR/${STACK}VersionTemplateMap.txt"
    else
    	# KuduLite Image, add single image support
        local TestRepoTagUpperCase="${TEST_IMAGE_REPO_NAME}/${STACK}:${PIPELINE_BUILD_NUMBER}"
        local TestRepoTag="${TestRepoTagUpperCase,,}"
        local appSvcDockerfilePath="${SYSTEM_ARTIFACTS_DIR}/${STACK}/GitRepo/kudu/Dockerfile"
        echo "Listing artifacts dir"
        ls "${SYSTEM_ARTIFACTS_DIR}"
        echo "Listing stacks dir"
        ls "${SYSTEM_ARTIFACTS_DIR}/${STACK}/GitRepo/kudu"
        cd "${SYSTEM_ARTIFACTS_DIR}/${STACK}/GitRepo/kudu"
        echo
        echo "Building test image with tag '$TestRepoTag' and file $appSvcDockerfilePath..."
        echo docker build -t "$TestRepoTag" -f "$appSvcDockerfilePath" .
        docker build -t "$TestRepoTag" -f "$appSvcDockerfilePath" .
	
	# only push the images if merging to the master
        if [ "$BUILD_REASON" != "PullRequest" ]; then
            docker push $TestRepoTag
        fi

        echo $TestRepoTag > $SYSTEM_ARTIFACTS_DIR/builtImageList
    fi
}

buildDockerImage
