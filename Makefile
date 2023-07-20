include ./scripts/init.mk
include ./scripts/test.mk

# This file contains hooks into the project configuration, test and build cycle
# as automated steps to be executed on a workstation and in the CI/CD pipeline.

config: # Configure development environment
	# TODO: Use only `make` targets that are specific to this project, e.g. you may not need to install Node.js
	make \
		asdf-install \
		githooks-install \
		nodejs-install \
		python-install \
		terraform-install

.SILENT: \
	config
