#!/bin/bash

ORIG_DIR=`pwd`

cd Tests/KuduLite/node/repository
git init
git config user.email "you@example.com"
git config user.name "Your Name"
git add .
git commit -m "init"

cd ../../dotnetcore/repository
git init
git config user.email "you@example.com"
git config user.name "Your Name"
git add .
git commit -m "init"

cd $ORIG_DIR
