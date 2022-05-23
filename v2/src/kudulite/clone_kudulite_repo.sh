#!/bin/bash
# --------------------------------------------------------------------------------------------
# This script clone Kudulite Repo
# --------------------------------------------------------------------------------------------

declare -r SYSTEM_ARTIFACTS_DIR="$1"                     # drop/ - when called from devops ; ../../output - when called from local
declare -r APPSVC_KUDULITE_REPO="$2"                     
declare -r APPSVC_KUDULITE_BRANCH="$3"   
declare -r APPSVC_KUDULITE_TYPE=$4                       # debian flavour of Kudu ( stretch / buster / bullseye)
declare -r APPSVC_REPO_DIR="$SYSTEM_ARTIFACTS_DIR/kudulite/GitRepo/$APPSVC_KUDULITE_TYPE"  
declare -r DIRECTORY_FROM_WHICH_THIS_FILES_IS_EXECUTED=`pwd`

echo "Cloning App Service KuduLiteBuild Repository in $APPSVC_REPO_DIR"
git clone $APPSVC_KUDULITE_REPO $APPSVC_REPO_DIR -b $APPSVC_KUDULITE_BRANCH

chmod -R 777 $DIRECTORY_FROM_WHICH_THIS_FILES_IS_EXECUTED/$APPSVC_REPO_DIR
echo