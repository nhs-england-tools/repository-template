# This file is for you! Edit it to implement your own Docker make targets.

# ==============================================================================
# Custom implementation - implementation of a make target should not exceed 5 lines of effective code.
# In most cases there should be no need to modify the existing make targets.

DOCKER_IMAGE ?= $(or ${docker_image}, $(or ${IMAGE}, $(or ${image}, ghcr.io/org/repo)))
DOCKER_TITLE ?= $(or "${docker_title}", $(or "${TITLE}", $(or "${title}", "Service Docker image")))

docker-bake-dockerfile: # Create Dockerfile.effective - optional: docker_dir|dir=[path to the image directory where the Dockerfile is located, default is '.'] @Development
	make _docker cmd="bake-dockerfile" \
		dir=$(or ${docker_dir}, ${dir})

docker-build: # Build Docker image - optional: docker_dir|dir=[path to the Dockerfile to use, default is '.'] @Development
	dir=$(or ${docker_dir}, ${dir})
	make _docker cmd="build"
docker-build: docker-lint

docker-lint: # Run hadolint over the Dockerfile - optional: docker_dir|dir=[path to the image directory where the Dockerfile is located, default is '.'] @Development
	dir=$(or ${docker_dir}, ${dir})
	make _docker cmd="lint"
docker-lint: docker-bake-dockerfile

docker-push: # Push Docker image - optional: docker_dir|dir=[path to the image directory where the Dockerfile is located, default is '.'] @Development
	make _docker cmd="push" \
		dir=$(or ${docker_dir}, ${dir})

docker-run: # Run Docker image - optional: docker_dir|dir=[path to the image directory where the Dockerfile is located, default is '.'] @Development
	make _docker cmd="run" \
		dir=$(or ${docker_dir}, ${dir})

clean:: # Remove Docker resources (docker) - optional: docker_dir|dir=[path to the image directory where the Dockerfile is located, default is '.'] @Operations
	make _docker cmd="clean" \
		dir=$(or ${docker_dir}, ${dir})

_docker: # Docker command wrapper - mandatory: cmd=[command to execute]; optional: dir=[path to the image directory where the Dockerfile is located, relative to the project's top-level directory, default is '.']
	# 'DOCKER_IMAGE' and 'DOCKER_TITLE' are passed to the functions as environment variables
	dir=$(realpath $(or ${dir}, infrastructure/images/${DOCKER_IMAGE}))
	source scripts/docker/docker.lib.sh
	docker-${cmd} # 'dir' is accessible by the function as environment variable

# ==============================================================================
# Quality checks - please DO NOT edit this section!

docker-shellscript-lint: # Lint all Docker module shell scripts @Quality
	for file in $$(find scripts/docker -type f -name "*.sh"); do
		file=$${file} scripts/shellscript-linter.sh
	done

# ==============================================================================
# Module tests and examples - please DO NOT edit this section!

docker-test-suite-run: # Run Docker test suite @ExamplesAndTests
	scripts/docker/tests/docker.test.sh

# ==============================================================================

${VERBOSE}.SILENT: \
	_docker \
	clean \
	docker-bake-dockerfile \
	docker-build \
	docker-lint \
	docker-push \
	docker-run \
	docker-shellscript-lint \
	docker-test-suite-run \
