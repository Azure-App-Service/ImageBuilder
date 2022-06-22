#!/bin/bash

stack="$1"
artifacts="$2"
isTestRunLocally=$3

if [ ! -z "$artifacts" ]
then
    echo "Artificats directory : $artifacts"
    ls $artifacts
    echo 

    testsDir="/home/vsts/work/1/s/Tests/$stack"

    if [[ ! -z "$isTestRunLocally" && "$isTestRunLocally" == "true" ]]; then
        testsDir="Tests/$stack"
    fi

    echo "Copying $artifacts/*builtImageList to $testsDir"
    cp -R $artifacts/*builtImageList $testsDir

    echo "Tests Directory : $testsDir"
    ls $testsDir
fi



if [ -z "$stack" ]
then
    dotnet test Tests/dotnetcore/Tests.csproj
    dotnet test Tests/php/Tests.csproj
    dotnet test Tests/python/Tests.csproj
    dotnet test Tests/node/Tests.csproj
    ./localSetupTests.sh
    dotnet test Tests/KuduLite/Tests.csproj
else
    if [ "$stack" == "dotnetcore" ] || [ "$stack" == "php" ] || [ "$stack" == "python" ] || [ "$stack" == "node" ]
    then
        dotnet test Tests/$stack/Tests.csproj
    elif [ "$stack" == "KuduLite" ]
    then
        ./localSetupTests.sh
        dotnet test Tests/$stack/Tests.csproj
    fi
fi
