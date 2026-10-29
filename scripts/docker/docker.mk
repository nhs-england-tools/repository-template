# This file is for you! Edit it to implement your own Docker make targets.

# ==============================================================================
# Custom implementation - implementation of a make target should not exceed 5
# lines of effective code.
# In most cases there should be no need to modify the existing make targets.

DOCKER_IMAGE ?= $(or ${docker_image}, $(or ${IMAGE}, $(or ${image}, ghcr.io/org/repo)))
DOCKER_TITLE ?= $(or "${docker_title}", $(or "${TITLE}", $(or "${title}", "Service Docker image")))
FORCE_USE_DOCKER ?= false

docker-bake-dockerfile: # Create Dockerfile.effective - optional: docker_dir|dir=[path to the image directory where the Dockerfile is located, default is '.'] @Build
	$(MAKE) _docker docker_fn="bake-dockerfile" \
		dir=$(or ${docker_dir}, ${dir})

docker-build: docker-lint
docker-build: # Build Docker image - optional: docker_dir|dir=[path to the Dockerfile to use, default is '.'] @Build
	$(MAKE) _docker docker_fn="build" \
		dir=$(or ${docker_dir}, ${dir})

docker-lint: docker-bake-dockerfile
docker-lint: # Run hadolint over the Dockerfile - optional: docker_dir|dir=[path to the image directory where the Dockerfile is located, default is '.'] @Quality
	$(MAKE) _docker docker_fn="lint" \
		dir=$(or ${docker_dir}, ${dir})

docker-push: # Push Docker image - optional: docker_dir|dir=[path to the image directory where the Dockerfile is located, default is '.'] @Release
	$(MAKE) _docker docker_fn="push" \
		dir=$(or ${docker_dir}, ${dir})

docker-run: # Run Docker image - optional: docker_dir|dir=[path to the image directory where the Dockerfile is located, default is '.'], cmd=[command to run in the container], args=[docker run options] @Development
	$(MAKE) _docker docker_fn="run" \
		dir=$(or ${docker_dir}, ${dir})

docker-pull-pinned-images: # Pull Docker images pinned in mise.toml [_.docker] @Configuration
	source scripts/docker/docker.lib.sh
	docker-pull-pinned-images

docker-test-suite-run: # Run Docker test suite @Quality
	dir=scripts/docker ./scripts/tests/run-test-suites.sh

_docker: # Docker function wrapper - mandatory: docker_fn=[function name, for example 'run']; optional: dir=[path to the image directory where the Dockerfile is located, relative to the project's top-level directory, default is '.']
	[[ -n "${docker_fn}" ]] || { echo "docker_fn is required, for example: make _docker docker_fn=run" >&2; exit 1; }
	# 'DOCKER_IMAGE' and 'DOCKER_TITLE' are passed to the functions as
	# environment variables
	dir=$(realpath $(or ${dir}, infrastructure/images/${DOCKER_IMAGE}))
	source scripts/docker/docker.lib.sh
	docker-${docker_fn} # 'dir' is accessible by the function as environment variable

clean:: # Remove Docker resources (docker) - optional: docker_dir|dir=[path to the image directory where the Dockerfile is located, default is '.'] @Operations
	$(MAKE) _docker docker_fn="clean" \
		dir=$(or ${docker_dir}, ${dir})

# ==============================================================================

${VERBOSE}.SILENT: \
	_docker \
	clean \
	docker-bake-dockerfile \
	docker-build \
	docker-lint \
	docker-pull-pinned-images \
	docker-push \
	docker-run \
	docker-test-suite-run \
