# This file is for you! Edit it to implement your own hooks (make targets) into
# the project as automated steps to be executed on locally and in the CD pipeline.

include ./scripts/init.mk
include ./scripts/test.mk

# Example targets are: dependencies, build, deploy, clean, etc.

dependencies:
	# TODO: Implement installation of your project dependencies

build:
	# TODO: Implement artefact build step

deploy:
	# TODO: Implement artefact deployment step

clean::
	# TODO: Implement project resources clean-up step

config:: # Configure development environment
	# TODO: Use only `make` targets that are specific to this project, e.g. you may not need to install Node.js
	make \
		nodejs-install \
		python-install \
		terraform-install

.SILENT: \
	build \
	clean \
	config \
	dependencies \
	deploy
