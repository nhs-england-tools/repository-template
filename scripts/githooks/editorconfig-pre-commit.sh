#!/bin/bash

docker run --rm --volume=$PWD:/check \
    mstruebing/editorconfig-checker \
        ec --exclude '.git/'
