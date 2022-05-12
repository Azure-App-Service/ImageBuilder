#!/bin/bash
# Usage : Generate docker file Kudulite HotPatch image
#   
# Example :
# $0 
# 

while getopts ":b:k:" opt; do
  case $opt in
    b) kuduliteBaseImageTag="$OPTARG"    
    ;;
    k) kuduliteBranch="$OPTARG"
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
        exit 1
    ;;
  esac
done


artifactStagingDirectory="output/DockerFiles"
baseImageName="${oryxBaseImageName:="mcr.microsoft.com/appsvc"}" 
baseImageVersion="${kuduliteBaseImageTag:="20220330.1"}" # Kudulite image which is taken in current ANT release
appSvcGitUrl="https://github.com/Azure-App-Service"
kuduliteBranch="${kuduliteBranch:="dev"}"
configDir="Config"

echo "Base Kudulite Image : $baseImageName/$baseImageVersion"
echo "Kudulite branch     : $kuduliteBranch"

echo ""
rm -rf $artifactStagingDirectory

function generateDockerFilesFor_KuduliteHotPatch()
{
    chmod u+x Kudulite-HotPatch/Scripts/generateDockerfilesforKuduliteHotPatchImage.sh
    local kuduliteRepoUrl="https://msazure.visualstudio.com/DefaultCollection/Antares/_git/AAPT-Antares-KuduLite"
    Kudulite-HotPatch/Scripts/generateDockerfilesforKuduliteHotPatchImage.sh $artifactStagingDirectory $baseImageName $baseImageVersion $kuduliteRepoUrl $configDir $kuduliteBranch
}

generateDockerFilesFor_KuduliteHotPatch