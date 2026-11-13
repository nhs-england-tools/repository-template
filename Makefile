include scripts/init.mk

# ==============================================================================
# Project targets

env: # Set up project environment @Configuration
	# TODO: Implement environment setup steps

deps: # Install dependencies needed to build and test the project @Build
	# TODO: Implement installation of your project dependencies

format: check ?= all
format: # Auto-format code (set check=all|staged-changes|working-tree-changes|branch) @Quality
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
	$(MAKE) lint-shell
	$(MAKE) lint-workflow-security
	$(MAKE) lint-pipeline-contract

typecheck: # Run type checker @Quality
	# TODO: Implement type checking required for this repository

test: # Run all tests @Quality
	./scripts/tests/run-test-suites.sh

check: # Run all format, lint, type and test checks @Quality
	$(MAKE) format
	$(MAKE) lint
	$(MAKE) typecheck
	$(MAKE) test

build: # Build the project artefact @Build
	# TODO: Implement the artefact build step

publish: # Publish the project artefact @Release
	# TODO: Implement the artefact publishing step

deploy: # Deploy the project artefact to the target environment @Release
	# TODO: Implement the artefact deployment step

config:: # Configure development environment (main) @Configuration
	# TODO: Implement project-specific configuration steps

clean:: # Clean-up project resources (main) @Operations
	# TODO: Implement project resources clean-up step

# ==============================================================================

${VERBOSE}.SILENT: \
	build \
	check \
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
