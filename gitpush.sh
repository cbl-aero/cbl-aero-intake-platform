#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: ./gitpush.sh \"commit message\""
  exit 1
fi

git add .
git commit -m "$1"
git push origin main
git log -1 --oneline