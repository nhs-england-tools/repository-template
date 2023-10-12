# This file is for you! Edit it to implement your own Docker make targets.

# ==============================================================================
# Custom implementation - implementation of a make target should not exceed 5 lines of effective code.
# In most cases there should be no need to modify the existing make targets.

docker-build: # Build Docker image - optional: docker_dir|dir=[path to the Dockerfile to use, default is '.'] @Development
	make _docker cmd="build" \
		dir=$(or ${docker_dir}, ${dir})
	file=$(or ${docker_dir}, ${dir})/Dockerfile.effective
	scripts/docker/dockerfile-linter.sh

docker-push: # Push Docker image - optional: docker_dir|dir=[path to the image directory where the Dockerfile is located, default is '.'] @Development
	make _docker cmd="push" \
		dir=$(or ${docker_dir}, ${dir})

clean:: # Remove Docker resources (docker) - optional: docker_dir|dir=[path to the image directory where the Dockerfile is located, default is '.'] @Operations
	make _docker cmd="clean" \
		dir=$(or ${docker_dir}, ${dir})

_docker: # Docker command wrapper - mandatory: cmd=[command to execute]; optional: dir=[path to the image directory where the Dockerfile is located, relative to the project's top-level directory, default is '.']
	# 'DOCKER_IMAGE' and 'DOCKER_TITLE' are passed to the functions as environment variables
	DOCKER_IMAGE=$(or ${DOCKER_IMAGE}, $(or ${docker_image}, $(or ${IMAGE}, $(or ${image}, ghcr.io/org/repo))))
	DOCKER_TITLE=$(or "${DOCKER_TITLE}", $(or "${docker_title}", $(or "${TITLE}", $(or "${title}", "Service Docker image"))))
	source scripts/docker/docker.lib.sh
	dir=$(realpath ${dir})
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

docker-example-build: # Build Docker example @ExamplesAndTests
	source scripts/docker/docker.lib.sh
	cd scripts/docker/examples/python
	DOCKER_IMAGE=repository-template/docker-example-python
	DOCKER_TITLE="Repository Template Docker Python Example"
	TOOL_VERSIONS="$(shell git rev-parse --show-toplevel)/scripts/docker/examples/python/.tool-versions.example"
	docker-build

docker-example-lint: # Lint Docker example @ExamplesAndTests
	dockerfile=scripts/docker/examples/python/Dockerfile
	file=$${dockerfile} scripts/docker/dockerfile-linter.sh

docker-example-run: # Run Docker example @ExamplesAndTests
	source scripts/docker/docker.lib.sh
	cd scripts/docker/examples/python
	DOCKER_IMAGE=repository-template/docker-example-python
	args=" \
		-it \
		--publish 8000:8000 \
	"
	docker-run

docker-example-clean: # Remove Docker example resources @ExamplesAndTests
	source scripts/docker/docker.lib.sh
	cd scripts/docker/examples/python
	DOCKER_IMAGE=repository-template/docker-example-python
	docker-clean

# ==============================================================================

${VERBOSE}.SILENT: \
	_docker \
	clean \
	docker-build \
	docker-example-build \
	docker-example-clean \
	docker-example-lint \
	docker-example-run \
	docker-push \
	docker-shellscript-lint \
	docker-test-suite-run \
