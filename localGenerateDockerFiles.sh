#!/bin/bash

# values from ImageBuilder/GenerateDockerFiles/dockerFilesGenerateTask.yml
artifactStagingDirectory="output/DockerFiles"
baseImageName="mcr.microsoft.com/oryx"
baseImageVersion="20210826.1" # change me as needed
appSvcGitUrl="https://github.com/Azure-App-Service"
configDir="Config"

rm -rf $artifactStagingDirectory

# Generate Node Docker Files
chmod u+x GenerateDockerFiles/node/generateDockerfiles.sh
GenerateDockerFiles/node/generateDockerfiles.sh $artifactStagingDirectory $baseImageName $baseImageVersion $appSvcGitUrl $configDir

# Generate .NET Core Docker Files
chmod u+x GenerateDockerFiles/dotnetcore/generateDockerfiles.sh 
GenerateDockerFiles/dotnetcore/generateDockerfiles.sh $artifactStagingDirectory $baseImageName $baseImageVersion $appSvcGitUrl $configDir

# Generate Python Docker Files
chmod u+x GenerateDockerFiles/python/generateDockerfiles.sh
GenerateDockerFiles/python/generateDockerfiles.sh $artifactStagingDirectory $baseImageName $baseImageVersion $appSvcGitUrl $configDir

# Generate PHP Docker Files
chmod u+x GenerateDockerFiles/php/generateDockerfiles.sh
GenerateDockerFiles/php/generateDockerfiles.sh $artifactStagingDirectory $baseImageName $baseImageVersion $appSvcGitUrl $configDir

# Generate PHP Xdebug Docker Files
#chmod u+x GenerateDockerFiles/php-xdebug/generateDockerfiles.sh 
#GenerateDockerFiles/php-xdebug/generateDockerfiles.sh $artifactStagingDirectory mcr.microsoft.com/appsvc $BuildNumber $appSvcGitUrl $configDir

# Generate Ruby Docker Files
chmod u+x GenerateDockerFiles/ruby/generateDockerfiles.sh
GenerateDockerFiles/ruby/generateDockerfiles.sh $artifactStagingDirectory $appSvcGitUrl $configDir

# Generate KuduLite Docker Files
chmod u+x GenerateDockerFiles/KuduLite/generateDockerfiles.sh 
GenerateDockerFiles/KuduLite/generateDockerfiles.sh $artifactStagingDirectory $baseImageName $baseImageVersion $appSvcGitUrl $configDir
