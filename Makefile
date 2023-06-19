include scripts/init.mk

# This file contains hooks into the project configuration, test and build cycle
# as automated steps to be executed locally and in the CI/CD pipeline.

config: # Configure development environment
	make \
		githooks-install

.SILENT: \
	config
