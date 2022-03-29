#!/bin/bash
# Usage : Generate docker file
# Note: If stackname is not specified, dockerfile is generated for all stacks
# $0 [-s=<stack name>] [-b=<oryx base image name>] [-t=<oryx tag name>]
#   
# Example :
# $0 
# $0 -s python
# $0 -s python -b oryxtest/python -t 3.9
# 

# values from ImageBuilder/GenerateDockerFiles/dockerFilesGenerateTask.yml
while getopts ":b:t:s:k:" opt; do
  case $opt in
    b) oryxBaseImageName="$OPTARG"
    ;;
    t) oryxTagName="$OPTARG"
    ;;
    s) stackName="$OPTARG"
    ;;
    k) kuduliteBranch="$OPTARG"
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
        exit 1
    ;;
  esac
done

artifactStagingDirectory="output/DockerFiles"
baseImageName="${oryxBaseImageName:="mcr.microsoft.com/oryx"}" 
baseImageVersion="${oryxTagName:="20220308.4"}" # change me as needed
appSvcGitUrl="https://github.com/Azure-App-Service"
kuduliteBranch="${kuduliteBranch:="dev"}"
configDir="Config"

echo "Base Image          : $baseImageName"
echo "Base Image Version  : $baseImageVersion"
echo "Stack               : $stackName"
if [[ $stackName == "kudulite" ]];
then
echo "Kudulite dev branch : $kuduliteBranch"
fi

echo ""
rm -rf $artifactStagingDirectory

function generateDockerFilesFor_Node()
{
    chmod u+x GenerateDockerFiles/node/generateDockerfiles.sh
    GenerateDockerFiles/node/generateDockerfiles.sh $artifactStagingDirectory $baseImageName $baseImageVersion $appSvcGitUrl $configDir
}

function generateDockerFilesFor_NetCore()
{
    chmod u+x GenerateDockerFiles/dotnetcore/generateDockerfiles.sh 
    GenerateDockerFiles/dotnetcore/generateDockerfiles.sh $artifactStagingDirectory $baseImageName $baseImageVersion $appSvcGitUrl $configDir
}

function generateDockerFilesFor_Python()
{
    chmod u+x GenerateDockerFiles/python/generateDockerfiles.sh
    GenerateDockerFiles/python/generateDockerfiles.sh $artifactStagingDirectory $baseImageName $baseImageVersion $appSvcGitUrl $configDir
}


function generateDockerFilesFor_PHP()
{
    chmod u+x GenerateDockerFiles/php/generateDockerfiles.sh
    GenerateDockerFiles/php/generateDockerfiles.sh $artifactStagingDirectory $baseImageName $baseImageVersion $appSvcGitUrl $configDir
}

# function generateDockerFilesFor_PHPXDebug()
# {
#     #chmod u+x GenerateDockerFiles/php-xdebug/generateDockerfiles.sh 
#     #GenerateDockerFiles/php-xdebug/generateDockerfiles.sh $artifactStagingDirectory mcr.microsoft.com/appsvc $BuildNumber $appSvcGitUrl $configDir
# }

function generateDockerFilesFor_Ruby()
{
    chmod u+x GenerateDockerFiles/ruby/generateDockerfiles.sh
    GenerateDockerFiles/ruby/generateDockerfiles.sh $artifactStagingDirectory $appSvcGitUrl $configDir
}

function generateDockerFilesFor_Wordpress()
{
    chmod u+x GenerateDockerFiles/wordpress/generateDockerfiles.sh
    GenerateDockerFiles/wordpress/generateDockerfiles.sh $artifactStagingDirectory $configDir
}

function generateDockerFilesFor_Kudulite()
{
    chmod u+x GenerateDockerFiles/KuduLite/generateDockerfiles.sh 
    local kuduliteRepoUrl="https://msazure.visualstudio.com/DefaultCollection/Antares/_git/AAPT-Antares-KuduLite"
    GenerateDockerFiles/KuduLite/generateDockerfiles.sh $artifactStagingDirectory $baseImageName $baseImageVersion $kuduliteRepoUrl $configDir $kuduliteBranch
}

if [[ -z $stackName ]]; then
    echo "Generating docker files for all stacks"
    generateDockerFilesFor_Node
    generateDockerFilesFor_NetCore
    generateDockerFilesFor_Python
    generateDockerFilesFor_PHP
    #generateDockerFilesFor_PHPXDebug
    generateDockerFilesFor_Ruby
    generateDockerFilesFor_Wordpress
    generateDockerFilesFor_Kudulite
    exit
fi

case $stackName in

  "node")
    generateDockerFilesFor_Node
    ;;

  "dotnetcore")
    generateDockerFilesFor_NetCore    
    ;;

  "python")
    generateDockerFilesFor_Python
    ;;

  "php")
    generateDockerFilesFor_PHP
    ;;

  "ruby")
    generateDockerFilesFor_Ruby
    ;;

  "wordpress")
    generateDockerFilesFor_Wordpress
    ;;

  "kudulite")
    generateDockerFilesFor_Kudulite
    ;;

  *)
    echo "Unable to generate docker file for stack : $stackName"
esac
