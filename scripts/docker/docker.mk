# This file is for you! Edit it to implement your own Docker make targets.

# ==============================================================================
# Custom implementation

DOCKER_IMAGE := ghcr.io/org/repo
DOCKER_TITLE := My Docker image

docker-build: # Build Docker image - optional: dir=[path to the Dockerfile to use, default is '.']
	source ./scripts/docker/docker.lib.sh
	docker-build

clean:: # Remove Docker resources
	source ./scripts/docker/docker.lib.sh
	docker-clean

# ==============================================================================
# Module tests and examples

docker-test-suite-run: # Run Docker test suite
	./scripts/docker/tests/docker.test.sh

docker-example-build: # Build Docker example
	source ./scripts/docker/docker.lib.sh
	cd ./scripts/docker/examples/python
	DOCKER_IMAGE=repository-template/docker-example-python
	DOCKER_TITLE="Repository Template Docker Python Example"
	docker-build

docker-example-lint: # Lint Docker example
	dockerfile=./scripts/docker/examples/python/Dockerfile
	file=$$dockerfile ./scripts/docker/dockerfile-linter.sh

docker-example-run: # Run Docker example
	source ./scripts/docker/docker.lib.sh
	cd ./scripts/docker/examples/python
	DOCKER_IMAGE=repository-template/docker-example-python
	args=" \
		-it \
		--publish 8000:8000 \
	"
	docker-run

# ==============================================================================
# Quality checks

docker-shellscript-lint: # Lint all Docker module shell scripts
	for file in $$(find ./scripts/docker -type f -name "*.sh"); do
		file=$$file ./scripts/shellscript-linter.sh
	done

# ==============================================================================

.SILENT: \
	clean \
	docker-build \
	docker-example-build \
	docker-example-lint \
	docker-example-run \
	docker-shellscript-lint \
	docker-test-suite-run \
