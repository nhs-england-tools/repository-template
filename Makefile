# This file is for you! Edit it to implement your own hooks (make targets) into
# the project as automated steps to be executed on locally and in the CD pipeline.

include ./scripts/init.mk
include ./scripts/test.mk

# This dependency list means that `make build` will only rebuild if
# any of the Dockerfiles in the `infrastructure/images` directory are
# newer than a timestamp file we leave under tmp/.  We're looking for
# 'Dockerfile*' so that, for instance, `Dockerfile.test` is spotted
SOURCES:=$(shell find infrastructure/images -name 'Dockerfile*') docker-compose.yaml

# Example targets are: dependencies, build, publish, deploy, clean, etc.

dependencies: # Install dependencies needed to build and test the project
	# TODO: Implement installation of your project dependencies

tmp/build_timestamp: $(SOURCES)
	make _project name="build"
	mkdir -p tmp
	touch tmp/build_timestamp

build: tmp/build_timestamp # Build the project for local execution

up: build # Run your code
	make _project name="up"

down: # Stop your code
	make _project name="down"

sh: up # Get a shell inside your running project, running it first if necessary
	make _project name="sh"

zpublish: # Publish the project artefact
	# TODO: Implement the artefact publishing step

deploy: # Deploy the project artefact to the target environment
	# TODO: Implement the artefact deployment step

clean:: # Clean-up project resources
	# TODO: Implement project resources clean-up step

config:: # Configure development environment
	# TODO: Use only `make` targets that are specific to this project, e.g. you may not need to install Node.js
	make \
		nodejs-install \
		python-install \
		terraform-install

_project:
	set -e
	SCRIPT="./scripts/projecthooks/${name}.sh"
	if [ -e "$${SCRIPT}" ]; then
		exec $$SCRIPT
	else
		echo "make ${name} not implemented: $${SCRIPT} not found" >&2
	fi

.SILENT: \
	_project \
	build \
	clean \
	config \
	dependencies \
	deploy \
	down \
	sh \
	tmp/build_timestamp \
	up \
