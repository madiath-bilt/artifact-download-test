#!/bin/bash

set -e

BRANCH=$(git branch --show-current)
REPO_DIR=/tmp/maven-$BRANCH

rm -rf $REPO_DIR
time ./compile.sh $REPO_DIR