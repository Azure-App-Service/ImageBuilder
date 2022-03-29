#!/bin/bash
# Usage : Build and tag docker image for stacks locally
# Note: If stackname is not specified, docker image for stacks would be build and tagged locally
# $0 buildNumber [-s=<stack name>]
# 
# Example :
# $0 testTag
# $0 testTag -s python
#

BuildNumber=$1
DockerFileDir=`pwd`"/output/DockerFiles"
shift
if [ -z "$BuildNumber" ]
then
    echo "please supply a build number"
    exit
fi

while getopts ":s:" opt; do
  case $opt in
    s) stackName="$OPTARG"
    ;;        
    \?) echo "Invalid option -$OPTARG" >&2
        exit 1
    ;;
  esac
done

echo "BuildNumber : $BuildNumber"
echo "Stack       : $stackName"
echo ""

function buildAndTagImages()
{
    local stackName=$1

    local githubRepo=$2 ;
    githubRepo="${githubRepo:="GitRepo"}" 

    local buildNumber=$3  
    buildNumber="${buildNumber:="$BuildNumber"}" 
    BuildAndTagImages/build.sh $DockerFileDir appsvctest "Config" $BuildNumber $stackName "PullRequest" $githubRepo $buildNumber
}



if [ -z "$stackName" ]
then
    echo "Building Images for all stacks"
    buildAndTagImages "node"
    buildAndTagImages "php"
    buildAndTagImages "php-xdebug"
    buildAndTagImages "python"
    buildAndTagImages "dotnetcore"
    buildAndTagImages "ruby"
    buildAndTagImages "wordpress"
    buildAndTagImages "kudulite"
    buildAndTagImages "kudulite" "GitRepo-DynInst" dynamic-$BuildNumber
    exit
fi

echo "Building and Tagging $stackName Images"
case $stackName in

  "node")
    buildAndTagImages "node"
    ;;

  "dotnetcore")
    buildAndTagImages "dotnetcore"
    ;;

  "python")
    buildAndTagImages "python"
    ;;

  "php")
    buildAndTagImages "php"
    ;;

  "ruby")
    buildAndTagImages "ruby"
    ;;

  "wordpress")
    buildAndTagImages "wordpress"
    ;;

  "kudulite")
    buildAndTagImages "kudulite"
    ;;

  "dynamic")
    buildAndTagImages "kudulite" "GitRepo-DynInst" dynamic-$BuildNumber
    ;;

  *)
    echo "Unable to Build and Tag Images for stack : $stack"
esac