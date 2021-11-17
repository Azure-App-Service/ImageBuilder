#!/bin/bash
BuildNumber=$1
DockerFileDir=`pwd`"/output/DockerFiles"

if [ -z "$BuildNumber" ]
then
    echo "please supply a build number"
    exit
fi

StackName="node"
BuildAndTagImages/build.sh $DockerFileDir appsvctest "Config" $BuildNumber $StackName "PullRequest" "GitRepo" $BuildNumber

StackName="php"
BuildAndTagImages/build.sh $DockerFileDir appsvctest "Config" $BuildNumber $StackName "PullRequest" "GitRepo" $BuildNumber

#StackName="php-xdebug"
#BuildAndTagImages/build.sh $DockerFileDir appsvctest "Config" $BuildNumber $StackName "PullRequest" "GitRepo" $BuildNumber

StackName="python"
BuildAndTagImages/build.sh $DockerFileDir appsvctest "Config" $BuildNumber $StackName "PullRequest" "GitRepo" $BuildNumber

StackName="dotnetcore"
BuildAndTagImages/build.sh $DockerFileDir appsvctest "Config" $BuildNumber $StackName "PullRequest" "GitRepo" $BuildNumber

StackName="ruby"
BuildAndTagImages/build.sh $DockerFileDir appsvctest "Config" $BuildNumber $StackName "PullRequest" "GitRepo" $BuildNumber

StackName="wordpress"
BuildAndTagImages/build.sh $DockerFileDir appsvctest "Config" $BuildNumber $StackName "PullRequest" "GitRepo" $BuildNumber

StackName="KuduLite"
BuildAndTagImages/build.sh $DockerFileDir appsvctest "Config" $BuildNumber $StackName "PullRequest" "GitRepo" $BuildNumber

# dynamic install
StackName="KuduLite"
BuildAndTagImages/build.sh $DockerFileDir appsvctest "Config" $BuildNumber $StackName "PullRequest" "GitRepo-DynInst" dynamic-$BuildNumber
