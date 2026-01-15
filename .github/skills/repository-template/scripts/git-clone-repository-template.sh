#!/bin/bash

cd "$(git rev-parse --show-toplevel)" || exit 1
cd .github/skills/repository-template
if ! [ -d "assets" ]; then
  git clone https://github.com/nhs-england-tools/repository-template.git assets
else
  cd assets
  git pull origin main
fi
