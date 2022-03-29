#!/usr/bin/env bash
cd src
sudo rm -rf bin obj publish
docker run --rm -v $(pwd):/src -w /src mcr.microsoft.com/dotnet/sdk:7.0 /bin/bash -c "dotnet restore && dotnet publish -o ./publish"
cd publish
zip -r ../../bin.zip *
rm -rf ../publish ../out ../obj ../bin
