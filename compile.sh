#!/bin/bash

set -e

REPO_DIR=$1

if [ -z "$REPO_DIR" ]; then
    echo "Error: Repository directory parameter required"
    exit 1
fi

if [ -d "$REPO_DIR" ]; then
    echo "Error: Repository directory $REPO_DIR already exists"
    exit 1
fi

./mvnw clean compile -Dmaven.repo.local=$REPO_DIR