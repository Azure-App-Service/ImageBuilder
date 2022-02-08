#!/bin/bash
# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT license.
# This script generates Dockerfiles for DiagnosticServer Image for Azure App Service on Linux.
# --------------------------------------------------------------------------------------------

set -e

# Current Working Dir
declare -r ORIG_DIR=`pwd`
declare -r DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
# Directory for Generated Docker Files
declare -r STACK_NAME="DiagnosticServer"
declare -r SYSTEM_ARTIFACTS_DIR="$1"
declare -r APPSVC_DIAGSERVER_REPO="$2"
declare -r CONFIG_DIR="$3"                                         # ${Current_Repo}/Config
declare -r METADATA_FILE="$SYSTEM_ARTIFACTS_DIR/metadata"
declare -r APP_SVC_REPO_DIR="$SYSTEM_ARTIFACTS_DIR/$STACK_NAME/GitRepo"
declare -r APP_SVC_REPO_BRANCH="main"

function generateDiagnosticServerDockerFiles()
{
    CURR_VERSION_DIRECTORY="${APP_SVC_REPO_DIR}/"
    TARGET_DOCKERFILE="${CURR_VERSION_DIRECTORY}/Dockerfile"

    # Register the generated docker files with metadata dir
    echo "${APP_SVC_REPO_DIR}, " > $METADATA_FILE

    echo "Done."
}

function pullAppSvcRepo()
{
    echo "Cloning App Service DiagnosticServer Repository in $APP_SVC_REPO_DIR"
    git clone $APPSVC_DIAGSERVER_REPO $APP_SVC_REPO_DIR
    cd $APP_SVC_REPO_DIR
    echo "Checking out branch $APP_SVC_REPO_BRANCH"
    git checkout $APP_SVC_REPO_BRANCH
    cd $ORIG_DIR
    chmod -R 777 $APP_SVC_REPO_DIR
}

pullAppSvcRepo
generateDiagnosticServerDockerFiles
