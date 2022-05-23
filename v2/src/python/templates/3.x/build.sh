#!/usr/bin/env bash
set -x -e

buildnumber=${4-$(date -u +"%y%m%d%H%M")}

docker build --no-cache -t "$1"/python:3.8_"$buildnumber" .
docker tag "$1"/python:3.7_"$buildnumber" "$1"/python:latest
