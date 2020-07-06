#!/bin/bash
BuildNumber=$1
DockerFileDir=`pwd`"/output/DockerFiles"

if [ -z "$BuildNumber" ]
then
    echo "please supply a build number"
    exit
fi

StackName="node"
BuildAndTagImages/build.sh $DockerFileDir appsvctest "Config" $BuildNumber $StackName "PullRequest"

StackName="php"
BuildAndTagImages/build.sh $DockerFileDir appsvctest "Config" $BuildNumber $StackName "PullRequest"

#StackName="php-xdebug"
#BuildAndTagImages/build.sh $DockerFileDir appsvctest "Config" $BuildNumber $StackName "PullRequest"

StackName="python"
BuildAndTagImages/build.sh $DockerFileDir appsvctest "Config" $BuildNumber $StackName "PullRequest"

StackName="dotnetcore"
BuildAndTagImages/build.sh $DockerFileDir appsvctest "Config" $BuildNumber $StackName "PullRequest"

StackName="ruby"
BuildAndTagImages/build.sh $DockerFileDir appsvctest "Config" $BuildNumber $StackName "PullRequest"

StackName="KuduLite"
BuildAndTagImages/build.sh $DockerFileDir appsvctest "Config" $BuildNumber $StackName "PullRequest"
