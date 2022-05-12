#!/bin/bash
# Usage : Build and tag docker image for Kudulite HotPatch locally
# 

BuildNumber=$1
DockerFileDir=`pwd`"/output/DockerFiles"
shift
if [ -z "$BuildNumber" ]
then
    echo "please supply a build number"
    exit
fi


function buildAndTagImages()
{
    local stackName=$1

    local githubRepo=$2 ;
    githubRepo="${githubRepo:="GitRepo"}" 

    local buildNumber=$3  
    buildNumber="${buildNumber:="$BuildNumber"}" 
    Kudulite-HotPatch/Scripts/buildKuduliteHotPatchImage.sh $DockerFileDir appsvctest "Config" $BuildNumber "kudulite" "PullRequest" $githubRepo $buildNumber $stackVersion
}

buildAndTagImages "kudulite"
buildAndTagImages "kudulite" "GitRepo-DynInst" buster_$BuildNumber