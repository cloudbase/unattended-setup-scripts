#!/bin/bash
set -e

n=$1

git fetch origin pull/$n/head
git checkout -b "pull$n" FETCH_HEAD

