#!/bin/bash
# --------------------------------------------------------------------------------------------
# Usage : Build and tag docker image for stacks locally
# Note: If stack_name is not specified, docker image for stacks would be build and tagged locally
# $0 [-s= stack name ]
#    [-v= stack version ]
#    [-k= kudulite type ]
#    [-t= tag name for the new image that will be built ]
#
# -t is mandatory parameter
# 
# Example :
# $0 
# $0 testTag -s python
#
# --------------------------------------------------------------------------------------------

declare -r IMAGEBUILDER_REPO_V2_SRC_FOLDER="../src"
declare -r DIRECTORY_FROM_WHICH_THIS_FILES_IS_EXECUTED="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
declare -r GENERATED_DOCKERFILES_DIRECTORY="$DIRECTORY_FROM_WHICH_THIS_FILES_IS_EXECUTED/../../output/DockerFiles"

while getopts ":s:v:k:t:" opt; do
  case $opt in
    s) STACK_NAME="$OPTARG"
    ;;        
    v) STACK_VERSION="$OPTARG"
    ;;        
    k) KUDULITE_TYPE="$OPTARG"
    ;;        
    t) BUILD_TAG="$OPTARG"
    ;;        
    \?) echo "Invalid option -$OPTARG" >&2
        exit 1
    ;;
  esac
done

if [ -z "$BUILD_TAG" ]
then
    current_date="$(date -u +"%y%m%d")"
    BUILD_TAG="test_$current_date.1"
    echo "warning : build tag is not specified. Using $BUILD_TAG" 
    echo   
fi

echo "Build Tag     : $BUILD_TAG"
echo "Stack         : $STACK_NAME"
echo "Stack Version : $STACK_VERSION"
echo ""

# Note: When using local development experience, we do not push images to wawsimages directory (as this is restricted)
# We pass the build reason as "Pull Request" which skips the code block that push images to mcr

# Summary : 
# This function helps in building the runtime images.
# 
# Arguments :
# 1 : stack_name
function build_and_tag_runtime_image()
{
  local stack_name=$1        
  local config_directory="$IMAGEBUILDER_REPO_V2_SRC_FOLDER/$stack_name"
  
  echo "Using local config directory as $config_directory"
  $IMAGEBUILDER_REPO_V2_SRC_FOLDER/build_runtime_images.sh $GENERATED_DOCKERFILES_DIRECTORY appsvctest $config_directory $BUILD_TAG "$stack_name" "PullRequest" "$STACK_VERSION"
}

# Summary : 
# This function helps in building the kudulite images
#
# Arguments :
function build_and_tag_kudulite_images()
{
  $IMAGEBUILDER_REPO_V2_SRC_FOLDER/kudulite/build_and_push_kudulite_images.sh $GENERATED_DOCKERFILES_DIRECTORY appsvctest "PullRequest" $BUILD_TAG $KUDULITE_TYPE
}

if [ -z "$STACK_NAME" ]
then
  echo "Building Images for all stacks"

  build_and_tag_runtime_image "python"    
  build_and_tag_kudulite_images

  exit
fi

echo "Building and Tagging $STACK_NAME Image"
echo 
case $STACK_NAME in

  "python")
    build_and_tag_runtime_image $STACK_NAME
    ;;

  "kudulite")
    build_and_tag_kudulite_images 
    ;;

  *)
    echo "Unable to Build and Tag Images for stack : $stack"
esac
