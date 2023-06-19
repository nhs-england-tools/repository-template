PROJECT_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
include $(abspath $(PROJECT_DIR)/scripts/init.mk)

# This file contains hooks into the project configuration, test and build cycle
# as automated steps to be executed locally and in the CI/CD pipeline.

config: # Configure development environment
	make \
		githooks-install \
		nodejs-install \
		python-install \
		terraform-install

.SILENT: \
	config
