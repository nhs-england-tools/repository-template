#!/bin/bash

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

# This file is for you! Edit it to run your application locally.  It
# is part of your local development infrastructure, so you can do
# whatever you need to make that as convenient as possible.

# By default we assume you're going to want containers to isolate your
# development environment, so we give you a basic docker-compose setup
# out of the box.
docker-compose down
