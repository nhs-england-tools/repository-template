#!/bin/bash

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

# This file is for you! Edit it to run your application locally.  It
# is part of your local development infrastructure, so you can do
# whatever you need to make that as convenient as possible.

# Usage: scripts/projecthooks/sh.sh [service] [shell]

# This script will connect to the docker-compose service named in the
# parameters, or default to the first listed in the docker-compose
# file.  You can pass a shell as a second parameter; it defaults to
# "sh" for compatibility but you might want to hardwire it to
# "/bin/bash" for features if your image has it.

# Note that we're using `exec` rather than `run` here.  Your image
# needs to be running, and you'll connect to a single instance.

service=${1:-$(docker-compose config --services | head -n1)}
shell=${2:-sh}
docker-compose exec $service $shell
