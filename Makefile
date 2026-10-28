include scripts/init.mk

# ==============================================================================
# Project targets

env: # Set up project environment @Configuration
	# TODO: Implement environment setup steps

deps: # Install dependencies needed to build and test the project @Build
	# TODO: Implement installation of your project dependencies

format: # Auto-format code @Quality
	$(MAKE) format-markdown

lint: check ?= all
lint: # Run linter to check code style and errors (set check=all|staged-changes|working-tree-changes|branch for the file checks) @Quality
	if [[ "$(check)" == branch ]]; then
		source scripts/quality/git-base.lib.sh
		quality-export-pr-base
	fi
	$(MAKE) lint-file-format
	$(MAKE) lint-markdown-format
	$(MAKE) lint-markdown-links
	$(MAKE) lint-shell check=all
	$(MAKE) lint-workflow-security

typecheck: # Run type checker @Quality
	# TODO: Implement type checking required for this repository

test: # Run all tests @Quality
	./scripts/tests/run-test-suites.sh

build: # Build the project artefact @Build
	# TODO: Implement the artefact build step

publish: # Publish the project artefact @Release
	# TODO: Implement the artefact publishing step

deploy: # Deploy the project artefact to the target environment @Release
	# TODO: Implement the artefact deployment step

clean:: # Clean-up project resources (main) @Operations
	# TODO: Implement project resources clean-up step

config:: # Configure development environment (main) @Configuration
	# TODO: Implement project-specific configuration steps

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
	publish \
	test \
	typecheck \
