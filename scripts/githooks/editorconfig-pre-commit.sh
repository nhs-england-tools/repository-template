#!/bin/bash
set -e

digest=0f8f8dd4f393d29755bef2aef4391d37c34e358d676e9d66ce195359a9c72ef3 # 2.7.0
docker run --rm --volume=$PWD:/check \
    mstruebing/editorconfig-checker@sha256:$digest \
        ec --exclude '.git/'
