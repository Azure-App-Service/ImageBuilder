#!/bin/bash

stack="$1"

artifacts="$2"
if [ ! -z "$artifacts" ]
then
    echo "$artifacts/drop/*builtImageList"
    echo "/home/vsts/work/1/s/Tests/$stack"
    cp -R $artifacts/drop/*builtImageList /home/vsts/work/1/s/Tests/$stack
fi



if [ -z "$stack" ]
then
    dotnet test Tests/dotnetcore/Tests.csproj
    dotnet test Tests/php/Tests.csproj
    dotnet test Tests/python/Tests.csproj
    dotnet test Tests/node/Tests.csproj
    dotnet test Tests/ruby/Tests.csproj
    ./localSetupTests.sh
    dotnet test Tests/KuduLite/Tests.csproj
else
    if [ "$stack" == "dotnetcore" ] || [ "$stack" == "php" ] || [ "$stack" == "python" ] || [ "$stack" == "node" ]  || [ "$stack" == "ruby" ] 
    then
        dotnet test Tests/$stack/Tests.csproj
    elif [ "$stack" == "KuduLite" ]
    then
        ./localSetupTests.sh
        dotnet test Tests/$stack/Tests.csproj
    fi
fi
