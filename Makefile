include scripts/init.mk

# ==============================================================================
# Project targets

env: # Set up project environment @Configuration
	# TODO: Implement environment setup steps

deps: # Install dependencies needed to build and test the project @Build
	# TODO: Implement installation of your project dependencies

format: # Auto-format code @Quality
	# TODO: Implement formatting required for this repository

lint-file-format: # Check file formats @Quality
	$(MAKE) check-file-format check=branch

lint-markdown-format: # Check markdown formatting @Quality
	$(MAKE) check-markdown-format check=branch

lint-markdown-links: # Check markdown links @Quality
	$(MAKE) check-markdown-links check=branch

lint: # Run linter to check code style and errors @Quality
	$(MAKE) lint-file-format
	$(MAKE) lint-markdown-format
	$(MAKE) lint-markdown-links

typecheck: # Run type checker @Quality
	# TODO: Implement type checking required for this repository

test: # Run all tests @Quality
	# TODO: Implement tests required for this repository

build: # Build the project artefact @Build
	# TODO: Implement the artefact build step

publish: # Publish the project artefact @Release
	# TODO: Implement the artefact publishing step

deploy: # Deploy the project artefact to the target environment @Release
	# TODO: Implement the artefact deployment step

clean:: # Clean-up project resources (main) @Operations
	# TODO: Implement project resources clean-up step

config:: # Configure development environment (main) @Configuration
	$(MAKE) _install-dependencies

# ==============================================================================

${VERBOSE}.SILENT: \
	build \
	clean \
	config \
	deploy \
	deps \
	env \
	format \
	lint \
	lint-file-format \
	lint-markdown-format \
	lint-markdown-links \
	publish \
	test \
	typecheck \
