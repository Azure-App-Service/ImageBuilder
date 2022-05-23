#!/bin/bash
# --------------------------------------------------------------------------------------------
# Usage : Generate Dockerfile and its dependencies for runtime images, kudulite, diagnostic server
# Note: If STACK_NAME is not specified, dockerfile is generated for all stacks ( including kudulite and diagnostic server)
# $0 [-o= oryx base image name ] 
#    [-t= oryx tag name ]
#    [-s= stack name ]
#    [-b= kudulite branch name ]
#    [-k= kudulite type ]
#   
# Examples :
# $0 
# $0 -s python
# $0 -s python -v 3.9 -o oryx/python 
# $0 -s kudulite -b releases/ant98 -k bullseye
# 
# $0 has the vaue of current filename in bash
# --------------------------------------------------------------------------------------------

while getopts ":o:t:s:v:b:k:" opt; do
  case $opt in
    o) ORYX_BASE_IMAGE_NAME="$OPTARG"
    ;;
    t) ORYX_TAG="$OPTARG"
    ;;
    s) STACK_NAME="$OPTARG"
    ;;
    v) STACK_VERSION="$OPTARG"
    ;;
    b) KUDULITE_BRANCH="$OPTARG"
    ;;
    k) KUDULITE_TYPE="$OPTARG"
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
        exit 1
    ;;
  esac
done

# Setting default values if not specified
oryx_base_image_name="${ORYX_BASE_IMAGE_NAME:="mcr.microsoft.com/oryx"}" 
oryx_base_image_version="${ORYX_TAG:="20220502.2"}" # change me as needed
kudulite_branch="${KUDULITE_BRANCH:="dev"}"

# Declaring constants
declare -r IMAGEBUILDER_REPO_V2_SRC_FOLDER="../src"
declare -r DIRECTORY_FROM_WHICH_THIS_FILES_IS_EXECUTED="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
declare -r OUTPUT_DIRECTORY="$DIRECTORY_FROM_WHICH_THIS_FILES_IS_EXECUTED/../../output/DockerFiles"

echo "Base Image          : $oryx_base_image_name"
echo "Base Image Version  : $oryx_base_image_version"
echo "Stack               : $STACK_NAME"
echo "Stack Version       : $STACK_VERSION"

if [[ $STACK_NAME == "kudulite" ]]; then
  echo "Kudulite dev branch : $kudulite_branch"
  echo "kudulite Type       : $KUDULITE_TYPE"  
fi

echo

# By default we delete all contents of output/Dockerfiles directory to start from clean state
# if stack and stackversion are specfied, then we delete only this directory
directory_to_remove=$OUTPUT_DIRECTORY

if [[ ! -z $STACK_NAME ]];
then
  if [[ ! -z $STACK_VERSION ]]; then
    directory_to_remove="$OUTPUT_DIRECTORY/$STACK_NAME/GitRepo/$STACK_VERSION"
  else
    directory_to_remove="$OUTPUT_DIRECTORY/$STACK_NAME"
  fi
fi

# Summary : 
# This function helps in Generating dockerfiles and its dependencies needed for building runtime image
#
# Arguments :
# stack_name
function generate_dockerfiles_for_runtime_images()
{
  local stack_name=$1
  local config_directory="../src/$stack_name/"
  chmod u+x $IMAGEBUILDER_REPO_V2_SRC_FOLDER/generate_dockerfiles_for_runtime_images.sh
  $IMAGEBUILDER_REPO_V2_SRC_FOLDER/generate_dockerfiles_for_runtime_images.sh $stack_name $OUTPUT_DIRECTORY $oryx_base_image_name $oryx_base_image_version $config_directory $STACK_VERSION
}

# Summary : 
# This function helps in Generating dockerfiles and its dependencies needed for building Kudulite images
#
# Arguments :
function generate_dockerfiles_for_kudulite()
{
  local kuduliteRepoUrl="https://msazure.visualstudio.com/DefaultCollection/Antares/_git/AAPT-Antares-KuduLite"
  chmod u+x $IMAGEBUILDER_REPO_V2_SRC_FOLDER/kudulite/generate_dockerfiles_for_kudulite_images.sh
  $IMAGEBUILDER_REPO_V2_SRC_FOLDER/kudulite/generate_dockerfiles_for_kudulite_images.sh $OUTPUT_DIRECTORY $kuduliteRepoUrl $kudulite_branch "$KUDULITE_TYPE" $oryx_base_image_name $oryx_base_image_version #  $config_directory $STACK_VERSION
}

if [[ -z $STACK_NAME ]]; then
    echo "Generating docker files for all stacks"
    generate_dockerfiles_for_runtime_images "python"
    generate_dockerfiles_for_kudulite
    exit
fi

case $STACK_NAME in
  "python")
    generate_dockerfiles_for_runtime_images $STACK_NAME
    ;;
  "kudulite")
    generate_dockerfiles_for_kudulite
    ;;
  *)
    echo "Unable to generate docker file for stack : $STACK_NAME"
esac
