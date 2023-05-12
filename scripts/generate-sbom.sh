#!/bin/bash

# ?
#
# Usage:
#   $ ./generate-sbom.sh

# ==============================================================================

image_digest=8b11ac4d8d15f598c7523f149a6b65be8540102f3665e4fdaa0d8231fd115092 # v0.80.0

docker run --rm --platform linux/amd64 \
    --volume $PWD:/project \
    --workdir /project \
    anchore/syft@sha256:$image_digest \
    ./ --output spdx-json=./sbom-spdx-$(date +'%Y%m%d%H%M%S').json
