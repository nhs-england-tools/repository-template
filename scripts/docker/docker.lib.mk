# Shared Docker and Compose targets. 'scripts/init.mk' loads this library once,
# before any module. Extend these targets from a project module, for example
# with 'docker-build: my-prerequisite', rather than editing or replacing them.
# Load it elsewhere only with '$(call include-once,docker/docker.lib.mk)'.
# See docs/guides/template/Use_Bash_and_Make.md#make-modules

# ==============================================================================
# Docker and Compose recipes run in the caller's directory, so a service
# Makefile builds the image or Compose stack next to it. A recipe should not
# exceed 5 lines of effective code, so larger logic lives in docker.lib.sh.

DOCKER_IMAGE ?= $(or ${docker_image}, ${IMAGE}, ${image})
DOCKER_TITLE ?= $(or ${docker_title}, ${TITLE}, ${title})
DOCKER_PLATFORM ?= linux/amd64
FORCE_USE_DOCKER ?= true

docker-compose-build: # Build Compose services - optional: compose_dir|dir=[directory with the Compose file, default is the top level, else the only one found], file=[Compose file instead of dir], project=[project name, default is the Compose default] @Build
	$(MAKE) -C "$(CURDIR)" -f "$(MAKE_ENTRY_POINT)" _docker docker_fn="compose-build" dir=. \
		compose_dir=$(or ${compose_dir}, ${dir})

docker-compose-up: # Start Compose services - optional: compose_dir|dir=[directory with the Compose file, default is the top level, else the only one found], file=[Compose file instead of dir], project=[project name, default is the Compose default] @Development
	$(MAKE) -C "$(CURDIR)" -f "$(MAKE_ENTRY_POINT)" _docker docker_fn="compose-up" dir=. \
		compose_dir=$(or ${compose_dir}, ${dir})

docker-compose-down: # Stop Compose services - optional: compose_dir|dir=[directory with the Compose file, default is the top level, else the only one found], file=[Compose file instead of dir], project=[project name, default is the Compose default] @Operations
	$(MAKE) -C "$(CURDIR)" -f "$(MAKE_ENTRY_POINT)" _docker docker_fn="compose-down" dir=. \
		compose_dir=$(or ${compose_dir}, ${dir})

docker-compose-status: # Show Compose status - optional: compose_dir|dir=[directory with the Compose file, default is the top level, else the only one found], file=[Compose file instead of dir], project=[project name, default is the Compose default] @Operations
	$(MAKE) -C "$(CURDIR)" -f "$(MAKE_ENTRY_POINT)" _docker docker_fn="compose-status" dir=. \
		compose_dir=$(or ${compose_dir}, ${dir})

docker-compose-logs: # Print recent Compose logs - optional: compose_dir|dir=[directory with the Compose file, default is the top level, else the only one found], file=[Compose file instead of dir], project=[project name, default is the Compose default] @Operations
	$(MAKE) -C "$(CURDIR)" -f "$(MAKE_ENTRY_POINT)" _docker docker_fn="compose-logs" dir=. \
		compose_dir=$(or ${compose_dir}, ${dir})

docker-compose-clean: # Remove Compose resources - optional: compose_dir|dir=[directory with the Compose file, default is the top level, else the only one found], file=[Compose file instead of dir], project=[project name, default is the Compose default] @Operations
	$(MAKE) -C "$(CURDIR)" -f "$(MAKE_ENTRY_POINT)" _docker docker_fn="compose-clean" dir=. \
		compose_dir=$(or ${compose_dir}, ${dir})

docker-bake-dockerfile: # Create Dockerfile.effective - optional: docker_dir|dir=[image directory, default is 'infrastructure/images/<image>' at the repository root when DOCKER_IMAGE is set, otherwise '.'] @Build
	$(MAKE) -C "$(CURDIR)" -f "$(MAKE_ENTRY_POINT)" _docker docker_fn="bake-dockerfile" \
		dir=$(or ${docker_dir}, ${dir})

docker-build: docker-lint
docker-build: # Build Docker image - optional: docker_dir|dir=[image directory, default is 'infrastructure/images/<image>' at the repository root when DOCKER_IMAGE is set, otherwise '.'] @Build
	$(MAKE) -C "$(CURDIR)" -f "$(MAKE_ENTRY_POINT)" _docker docker_fn="build" \
		dir=$(or ${docker_dir}, ${dir})

docker-lint: docker-bake-dockerfile
docker-lint: # Run hadolint over the Dockerfile - optional: docker_dir|dir=[image directory, default is 'infrastructure/images/<image>' at the repository root when DOCKER_IMAGE is set, otherwise '.'] @Quality
	$(MAKE) -C "$(CURDIR)" -f "$(MAKE_ENTRY_POINT)" _docker docker_fn="lint" \
		dir=$(or ${docker_dir}, ${dir})

docker-push: # Push Docker image - optional: docker_dir|dir=[image directory, default is 'infrastructure/images/<image>' at the repository root when DOCKER_IMAGE is set, otherwise '.'] @Release
	$(MAKE) -C "$(CURDIR)" -f "$(MAKE_ENTRY_POINT)" _docker docker_fn="push" \
		dir=$(or ${docker_dir}, ${dir})

docker-run: # Run Docker image - optional: docker_dir|dir=[image directory, default is 'infrastructure/images/<image>' at the repository root when DOCKER_IMAGE is set, otherwise '.'], cmd=[command to run in the container], args=[docker run options] @Development
	$(MAKE) -C "$(CURDIR)" -f "$(MAKE_ENTRY_POINT)" _docker docker_fn="run" \
		dir=$(or ${docker_dir}, ${dir})

docker-pull-pinned-images: # Pull Docker images pinned in mise.toml [_.docker] @Configuration
	source "$(REPOSITORY_SCRIPTS_DIR)/docker/docker.lib.sh"
	docker-pull-pinned-images

docker-test-suite-run: # Run Docker test suite @Quality
	dir=scripts/docker "$(REPOSITORY_SCRIPTS_DIR)/tests/run-test-suites.sh"

_docker: # Docker function wrapper - mandatory: docker_fn=[function name, for example 'run']; optional: dir=[image directory, relative to the directory Make runs in]
	source "$(REPOSITORY_SCRIPTS_DIR)/cicd/github-actions.lib.sh"
	[[ -n "${docker_fn}" ]] || { print-diagnostic error "docker_fn is required, for example: make _docker docker_fn=run"; exit 1; }
	# The root keeps its image layout, any other directory is the image directory
	requested="$(or ${dir},$(if $(subst $(REPOSITORY_ROOT_DIR),,$(CURDIR)),.,$(if ${DOCKER_IMAGE},infrastructure/images/${DOCKER_IMAGE},.)))"
	dir="$$(cd "$$requested" 2> /dev/null && pwd -P)" || { print-diagnostic error "Docker image directory not found: $$requested. Pass an existing dir, or dir=. for the directory Make runs in"; exit 1; }
	# DOCKER_IMAGE and DOCKER_TITLE reach the functions as environment variables
	source "$(REPOSITORY_SCRIPTS_DIR)/docker/docker.lib.sh"
	docker-${docker_fn} # 'dir' is accessible by the function as environment variable

clean:: # Remove Docker resources (docker) - optional: docker_dir|dir=[image directory, default is 'infrastructure/images/<image>' at the repository root when DOCKER_IMAGE is set, otherwise '.'] @Operations
	$(MAKE) -C "$(CURDIR)" -f "$(MAKE_ENTRY_POINT)" _docker docker_fn="clean" \
		dir=$(or ${docker_dir}, ${dir})

# ==============================================================================

${VERBOSE}.SILENT: \
	_docker \
	clean \
	docker-bake-dockerfile \
	docker-build \
	docker-compose-build \
	docker-compose-clean \
	docker-compose-down \
	docker-compose-logs \
	docker-compose-status \
	docker-compose-up \
	docker-lint \
	docker-pull-pinned-images \
	docker-push \
	docker-run \
	docker-test-suite-run \
