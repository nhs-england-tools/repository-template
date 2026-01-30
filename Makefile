include scripts/init.mk

# ==============================================================================
# Project targets

format: # Auto-format code @Quality
	# No formatting required for this repository

lint-file-format: # Check file formats @Quality
	$(MAKE) check-file-format check=branch

lint-markdown-format: # Check markdown formatting @Quality
	$(MAKE) check-markdown-format check=branch

lint: # Run linter to check code style and errors @Quality
	$(MAKE) lint-file-format
	$(MAKE) lint-markdown-format

test: # Run all tests @Testing
	# No tests required for this repository

# ==============================================================================
# CI/CD targets

dependencies: # Install dependencies needed to build and test the project @Pipeline
	# TODO: Implement installation of your project dependencies

build: # Build the project artefact @Pipeline
	# TODO: Implement the artefact build step

publish: # Publish the project artefact @Pipeline
	# TODO: Implement the artefact publishing step

deploy: # Deploy the project artefact to the target environment @Pipeline
	# TODO: Implement the artefact deployment step

clean:: # Clean-up project resources (main) @Operations
	# TODO: Implement project resources clean-up step

config:: # Configure development environment (main) @Configuration
	# TODO: Use only 'make' targets that are specific to this project, e.g. you may not need to install Node.js
	make _install-dependencies

# ==============================================================================

${VERBOSE}.SILENT: \
	build \
	clean \
	config \
	dependencies \
	deploy \
	format \
	lint \
	lint-file-format \
	lint-markdown-format \
	test \
