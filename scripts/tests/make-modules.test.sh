#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2317,SC2329

set -euo pipefail

# Test suite for the Make module loader in 'scripts/init.mk'. Each test copies
# the core Makefiles into a scratch directory, adds fixture modules and
# libraries under 'scripts/' and runs make there or from a service directory.
#
# Usage:
#   $ ./scripts/tests/make-modules.test.sh
#
# Arguments (provided as environment variables):
#   VERBOSE=true  # Show all the executed commands, default is 'false'

# ==============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/test.lib.sh"

readonly EXIT_STATUS_LABEL='exit status'

function main() {

  cd "$(git rev-parse --show-toplevel)"

  # Caller Make and Docker settings must not reach the Makefiles under test
  unset -v MAKEFLAGS MAKELEVEL GNUMAKEFLAGS MAKEFILES MFLAGS INIT_MK_INCLUDED \
    DOCKER_IMAGE docker_image IMAGE image DOCKER_TITLE docker_title TITLE title \
    DOCKER_PLATFORM FORCE_USE_DOCKER dir docker_dir compose_dir file project cmd args \
    CONFIRM UNTRACKED UNSTAGED GITHUB_ACTIONS

  test-run-suite \
    test-make-runs-without-modules \
    test-make-lists-raw-variable-definitions \
    test-make-ignores-an-inherited-include-marker \
    test-make-loads-root-and-nested-modules \
    test-make-loads-symlinked-modules \
    test-make-lists-module-targets-in-help \
    test-make-ignores-libraries-unless-included \
    test-make-loads-a-library-included-by-a-module \
    test-make-loads-a-shared-library-once \
    test-make-loads-modules-in-full-path-order \
    test-make-builds-each-module-image-for-its-platform \
    test-make-keeps-a-module-platform-over-the-environment \
    test-make-lets-the-command-line-override-a-module-platform \
    test-make-keeps-a-module-platform-in-a-service \
    test-make-loads-the-docker-library-once \
    test-make-loads-core-files-once \
    test-make-fails-on-a-malformed-module \
    test-make-gives-modules-absolute-repository-paths \
    test-make-works-in-a-path-with-spaces \
    test-make-runs-from-a-service-directory \
    test-make-runs-a-service-makefile-selected-with-f \
    test-make-keeps-unnamed-module-hooks-out-of-a-service \
    test-make-loads-a-module-once-when-the-root-names-it \
    test-make-ignores-init-included-twice \
    test-make-ignores-a-repeated-docker-library-include \
    test-make-lints-a-service-dockerfile \
    test-docker-lints-a-relative-service-directory \
    test-make-defaults-to-the-service-dockerfile \
    test-make-runs-compose-in-the-service-directory \
    test-make-keeps-the-root-dockerfile-default \
    test-make-rejects-a-missing-docker-directory \
    test-make-rejects-a-missing-root-image-directory \
    test-make-defaults-to-the-root-without-an-image-name \
    test-make-reports-missing-mise-as-a-diagnostic \
    test-make-reports-untrusted-mise-config-as-a-diagnostic \
    test-make-reports-a-missing-tool-name-as-a-diagnostic \
    test-make-runs-shared-cleanup-at-the-repository-root \
    test-make-keeps-the-service-directory-for-version-files

  return 0
}

# ==============================================================================

function test-make-runs-without-modules() {

  # Arrange
  copy-core
  # Act
  run-make help
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDOUT" "Usage:"

  return 0
}

function test-make-lists-raw-variable-definitions() {

  # Arrange
  copy-core
  # shellcheck disable=SC2016 # These are Make references, not shell ones
  printf '%s\n' \
    'FIXTURE_BASE := example' \
    'FIXTURE_DERIVED = $(FIXTURE_BASE)-value' \
    'fixture-function = $(error do not evaluate)' \
    'FIXTURE_PASSWORD := secret-fixture-value' \
    > "$TEST_TMP/tree/scripts/fixture.mk"
  # Act
  run-make list-variables
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-contains "$TEST_STDOUT" 'FIXTURE_BASE=example'
  assert-contains "$TEST_STDOUT" "FIXTURE_DERIVED=\$(FIXTURE_BASE)-value"
  assert-contains "$TEST_STDOUT" "fixture-function=\$(error do not evaluate)"
  assert-contains "$TEST_STDOUT" 'FIXTURE_PASSWORD=****** [simple,file]'
  assert-not-contains "$TEST_STDOUT" 'secret-fixture-value'

  return 0
}

function test-make-ignores-an-inherited-include-marker() {

  # Arrange
  copy-core
  # Act
  INIT_MK_INCLUDED=true run-make help
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-contains "$TEST_STDOUT" "docker-build"

  return 0
}

function test-make-loads-root-and-nested-modules() {

  # Arrange
  copy-core
  write-module scripts/root.mk root-module
  write-module scripts/a/b/c/deep.mk deep-module
  # Act
  run-make root-module deep-module
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDOUT" "root-module-ran"
  assert-contains "$TEST_STDOUT" "deep-module-ran"

  return 0
}

function test-make-loads-symlinked-modules() {

  # Arrange
  copy-core
  write-module shared/linked.mk linked-module
  ln -s ../shared/linked.mk "$TEST_TMP/tree/scripts/linked.mk"
  # Act
  run-make linked-module
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDOUT" "linked-module-ran"

  return 0
}

function test-make-lists-module-targets-in-help() {

  # Arrange
  copy-core
  write-module scripts/team/team.mk team-module
  # Act
  run-make help
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDOUT" "team-module"

  return 0
}

function test-make-ignores-libraries-unless-included() {

  # Arrange
  copy-core
  write-module scripts/team/orphan.lib.mk orphan-target
  # Act
  run-make orphan-target
  # Assert
  assert-equal 2 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "No rule to make target 'orphan-target'"

  return 0
}

function test-make-loads-a-library-included-by-a-module() {

  # Arrange
  copy-core
  write-module scripts/team/team.lib.mk library-target
  write-module scripts/team/team.mk team-module
  # shellcheck disable=SC2016 # Make references, not shell ones
  printf '%s\n' '$(call include-once,team/team.lib.mk)' >> "$TEST_TMP/tree/scripts/team/team.mk"
  # Act
  run-make library-target team-module
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-contains "$TEST_STDOUT" "library-target-ran"
  assert-contains "$TEST_STDOUT" "team-module-ran"

  return 0
}

function test-make-loads-a-shared-library-once() {

  local module

  # Arrange
  copy-core
  mkdir -p "$TEST_TMP/tree/scripts/shared"
  # A shell 'else' at the start of a recipe line broke include-guarded files
  printf '%s\n' 'shared-target:' $'\tif false; then' $'\t\techo wrong' $'\telse' $'\t\techo shared-target-ran' $'\tfi' \
    > "$TEST_TMP/tree/scripts/shared/shared.lib.mk"
  for module in a b; do
    # shellcheck disable=SC2016 # Make references, not shell ones
    printf '%s\n' '$(call include-once,shared/shared.lib.mk)' > "$TEST_TMP/tree/scripts/$module.mk"
  done
  # Act
  run-make shared-target
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-contains "$TEST_STDOUT" "shared-target-ran"
  assert-not-contains "$TEST_STDERR" "warning"

  return 0
}

function test-make-loads-modules-in-full-path-order() {

  # Arrange
  copy-core
  mkdir -p "$TEST_TMP/tree/scripts/a" "$TEST_TMP/tree/scripts/z"
  echo 'ORDER += a/01' > "$TEST_TMP/tree/scripts/a/01-second.mk"
  echo 'ORDER += a/00' > "$TEST_TMP/tree/scripts/a/00-first.mk"
  echo 'ORDER += c' > "$TEST_TMP/tree/scripts/c.mk"
  echo 'ORDER += b' > "$TEST_TMP/tree/scripts/b.mk"
  echo 'ORDER += a' > "$TEST_TMP/tree/scripts/a.mk"
  echo 'ORDER += lib' > "$TEST_TMP/tree/scripts/a/a.lib.mk"
  # shellcheck disable=SC2016 # '$(ORDER)' is a Make reference, not a shell one
  printf 'ORDER += z/00\nprint-order:\n\t@echo "order=$(ORDER)"\n' > "$TEST_TMP/tree/scripts/z/00-last.mk"
  # Act
  run-make print-order
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDOUT" "order=a a/00 a/01 b c z/00"

  return 0
}

function test-make-builds-each-module-image-for-its-platform() {

  # Arrange
  prepare-platform-modules
  # Act
  FORCE_USE_DOCKER=false run-make images
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-equal linux/arm64 "$(built-platform orders)" "Orders platform"
  assert-equal linux/amd64 "$(built-platform billing)" "Billing platform"

  return 0
}

function test-make-keeps-a-module-platform-over-the-environment() {

  # Arrange
  prepare-platform-modules
  # Act
  DOCKER_PLATFORM=linux/s390x FORCE_USE_DOCKER=false run-make images
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-equal linux/arm64 "$(built-platform orders)" "Orders platform"
  assert-equal linux/s390x "$(built-platform billing)" "Billing platform"

  return 0
}

function test-make-lets-the-command-line-override-a-module-platform() {

  # Arrange
  prepare-platform-modules
  # Act
  FORCE_USE_DOCKER=false run-make images DOCKER_PLATFORM=linux/s390x
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-equal linux/s390x "$(built-platform orders)" "Orders platform"
  assert-equal linux/s390x "$(built-platform billing)" "Billing platform"

  return 0
}

function test-make-keeps-a-module-platform-in-a-service() {

  # Arrange
  prepare-platform-modules
  # shellcheck disable=SC2016 # Make references, not shell ones
  printf '%s\n' '$(call include-once,orders/orders.mk)' >> "$TEST_TMP/tree/services/api/Makefile"
  # Act
  test-capture env FORCE_USE_DOCKER=false make --no-print-directory -C "$TEST_TMP/tree/services/api" orders-image
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-equal linux/arm64 "$(built-platform orders)" "Orders platform"

  return 0
}

function test-make-loads-the-docker-library-once() {

  # Arrange
  copy-core
  # Act
  run-make help
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDOUT" "docker-build"
  assert-not-contains "$TEST_STDERR" "overriding recipe"
  assert-not-contains "$TEST_STDERR" "ignoring old recipe"

  return 0
}

function test-make-loads-core-files-once() {

  # Arrange
  copy-core
  write-module scripts/team/team.mk team-module
  # Act
  run-make help
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-not-contains "$TEST_STDERR" "overriding recipe"

  return 0
}

function test-make-fails-on-a-malformed-module() {

  # Arrange
  copy-core
  mkdir -p "$TEST_TMP/tree/scripts/broken"
  echo 'this is not make syntax' > "$TEST_TMP/tree/scripts/broken/broken.mk"
  # Act
  run-make help
  # Assert
  assert-equal 2 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "broken.mk"

  return 0
}

function test-make-gives-modules-absolute-repository-paths() {

  local root

  # Arrange
  copy-core
  write-service-makefile
  root="$(cd "$TEST_TMP/tree" && pwd -P)"
  # shellcheck disable=SC2016 # Make references, not shell ones
  printf '%s\n' 'print-paths:' $'\t@cd / && echo "root=$(REPOSITORY_ROOT_DIR) scripts=$(REPOSITORY_SCRIPTS_DIR)"' \
    > "$TEST_TMP/tree/scripts/paths.mk"
  # shellcheck disable=SC2016 # Make references, not shell ones
  printf '%s\n' '$(call include-once,paths.mk)' >> "$TEST_TMP/tree/services/api/Makefile"
  # Act
  test-capture make --no-print-directory -C "$TEST_TMP/tree/services/api" print-paths
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-equal "root=$root scripts=$root/scripts" "$TEST_STDOUT" "repository paths"

  return 0
}

function test-make-works-in-a-path-with-spaces() {

  local tree="$TEST_TMP/with space/tree"

  # Arrange
  copy-core
  copy-docker-scripts
  write-module scripts/team/team.mk team-module
  write-service-makefile team/team.mk
  git init -q "$TEST_TMP/tree"
  mkdir -p "$TEST_TMP/with space"
  mv "$TEST_TMP/tree" "$tree"
  test-isolate-path make perl tput
  test-stub docker
  # Act
  test-capture make --no-print-directory -C "$tree" help team-module clean
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-contains "$TEST_STDOUT" "docker-build"
  assert-contains "$TEST_STDOUT" "team-module-ran"
  assert-contains "$TEST_STDOUT" "Git cleanup covers the whole repository at $(cd "$tree" && pwd -P)"
  # Act
  test-capture make --no-print-directory -C "$tree/services/api" team-module
  # Assert
  assert-equal 0 "$TEST_STATUS" "service $EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-contains "$TEST_STDOUT" "team-module-ran"

  return 0
}

function test-make-runs-from-a-service-directory() {

  # Arrange
  copy-core
  write-module scripts/team/team.mk team-module
  write-service-makefile team/team.mk
  # Act
  test-capture make --no-print-directory -C "$TEST_TMP/tree/services/api" help service-where team-module
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDOUT" "docker-build"
  assert-contains "$TEST_STDOUT" "where=$(cd "$TEST_TMP/tree/services/api" && pwd -P)"
  assert-contains "$TEST_STDOUT" "team-module-ran"
  assert-not-contains "$TEST_STDERR" "overriding recipe"

  return 0
}

function test-make-runs-a-service-makefile-selected-with-f() {

  # Arrange
  copy-core
  write-module scripts/team/team.mk team-module
  write-service-makefile team/team.mk
  # Act
  test-capture make --no-print-directory -C "$TEST_TMP/tree" -f services/api/Makefile service-recurse
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-contains "$TEST_STDOUT" "service-only-ran"
  assert-contains "$TEST_STDOUT" "team-module-ran"

  return 0
}

function test-make-keeps-unnamed-module-hooks-out-of-a-service() {

  local module

  # Arrange
  copy-core
  for module in orders billing; do
    write-module "scripts/$module/$module.mk" "$module-test"
    printf 'test: %s-test\n' "$module" >> "$TEST_TMP/tree/scripts/$module/$module.mk"
  done
  write-service-makefile orders/orders.mk
  # Act
  test-capture make --no-print-directory -C "$TEST_TMP/tree/services/api" test
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-contains "$TEST_STDOUT" "orders-test-ran"
  assert-not-contains "$TEST_STDOUT" "billing-test-ran"
  # Act
  run-make test
  # Assert
  assert-contains "$TEST_STDOUT" "orders-test-ran"
  assert-contains "$TEST_STDOUT" "billing-test-ran"

  return 0
}

function test-make-loads-a-module-once-when-the-root-names-it() {

  # Arrange
  copy-core
  write-module scripts/team/team.mk team-module
  # shellcheck disable=SC2016 # Make references, not shell ones
  printf '%s\n' '$(call include-once,team/team.mk)' >> "$TEST_TMP/tree/Makefile"
  # Act
  run-make team-module
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-contains "$TEST_STDOUT" "team-module-ran"
  assert-not-contains "$TEST_STDERR" "warning"

  return 0
}

function test-make-ignores-init-included-twice() {

  # Arrange
  copy-core
  write-service-makefile
  # shellcheck disable=SC2016 # Make references, not shell ones
  printf '%s\n' 'include $(SERVICE_DIR)../../scripts/init.mk' >> "$TEST_TMP/tree/services/api/Makefile"
  # Act
  test-capture make --no-print-directory -C "$TEST_TMP/tree/services/api" help
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-not-contains "$TEST_STDERR" "warning"
  assert-equal 1 "$(grep -c 'scan-secrets' <<< "$TEST_STDOUT")" "scan-secrets help entries"

  return 0
}

function test-make-ignores-a-repeated-docker-library-include() {

  # Arrange
  copy-core
  # shellcheck disable=SC2016 # Make references, not shell ones
  printf '%s\n' '$(call include-once,docker/docker.lib.mk)' > "$TEST_TMP/tree/scripts/team.mk"
  # Act
  run-make help
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-not-contains "$TEST_STDERR" "warning"
  assert-equal 1 "$(grep -c 'docker-push' <<< "$TEST_STDOUT")" "docker-push help entries"

  return 0
}

function test-make-lints-a-service-dockerfile() {

  # Arrange
  prepare-service-docker
  # Act
  test-capture env FORCE_USE_DOCKER=false DOCKER_IMAGE=service docker_dir=. \
    make --no-print-directory -C "$TEST_TMP/tree/services/api" docker-lint
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-file-exists "$TEST_TMP/tree/services/api/Dockerfile.effective"
  assert-contains "$(test-stub-calls hadolint)" "services/api/Dockerfile.effective"

  return 0
}

function test-docker-lints-a-relative-service-directory() {

  # Arrange
  prepare-service-docker
  touch "$TEST_TMP/tree/services/api/Dockerfile.effective"
  # Act
  # shellcheck disable=SC2016 # Arguments are expanded by the child shell
  test-capture env FORCE_USE_DOCKER=false bash -c \
    'cd "$1"; source "$2"; dir=. docker-lint' _ \
    "$TEST_TMP/tree/services/api" "$TEST_TMP/tree/scripts/docker/docker.lib.sh"
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-contains "$(test-stub-calls hadolint)" "services/api/Dockerfile.effective"

  return 0
}

function test-make-defaults-to-the-service-dockerfile() {

  # Arrange
  prepare-service-docker
  mkdir -p "$TEST_TMP/tree/services/api/infrastructure/images/service"
  cp "$TEST_TMP/tree/services/api/Dockerfile" "$TEST_TMP/tree/services/api/infrastructure/images/service/"
  cp "$TEST_TMP/tree/services/api/VERSION" "$TEST_TMP/tree/services/api/infrastructure/images/service/"
  # shellcheck disable=SC2016 # Stub code runs in a child shell
  test-stub docker 'if [[ "${1:-}" == build ]]; then pwd -P > "$TEST_TMP/docker-build-cwd"; fi'
  # shellcheck disable=SC2016 # Make reference, not a shell one
  printf '\nservice-build:\n\t%s\n' '$(MAKE) -C services/api docker-build' >> "$TEST_TMP/tree/Makefile"
  # Act
  test-capture env FORCE_USE_DOCKER=false DOCKER_IMAGE=service DOCKER_TITLE=service \
    make --no-print-directory -C "$TEST_TMP/tree" service-build
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-file-exists "$TEST_TMP/tree/services/api/Dockerfile.effective"
  assert-contains "$(test-stub-calls hadolint)" "services/api/Dockerfile.effective"
  assert-contains "$(test-stub-calls docker)" "services/api/Dockerfile.effective"
  assert-equal "$(cd "$TEST_TMP/tree/services/api" && pwd -P)" \
    "$(< "$TEST_TMP/docker-build-cwd")" "Docker build context"

  return 0
}

function test-make-runs-compose-in-the-service-directory() {

  # Arrange
  prepare-service-docker
  touch "$TEST_TMP/tree/compose.yaml" "$TEST_TMP/tree/services/api/compose.yaml"
  # shellcheck disable=SC2016 # Stub code runs in a child shell
  test-stub docker 'if [[ "${1:-} ${2:-}" == "compose up" ]]; then pwd -P > "$TEST_TMP/compose-cwd"; fi'
  # Act
  test-capture make --no-print-directory -C "$TEST_TMP/tree/services/api" docker-compose-up
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-equal "$(cd "$TEST_TMP/tree/services/api" && pwd -P)" \
    "$(< "$TEST_TMP/compose-cwd")" "Compose project directory"
  assert-contains "$(test-stub-calls docker)" "compose up --detach --wait"

  return 0
}

function test-make-keeps-the-root-dockerfile-default() {

  # Arrange
  prepare-service-docker
  mkdir -p "$TEST_TMP/tree/infrastructure/images/service"
  cp "$TEST_TMP/tree/services/api/Dockerfile" "$TEST_TMP/tree/infrastructure/images/service/"
  cp "$TEST_TMP/tree/services/api/VERSION" "$TEST_TMP/tree/infrastructure/images/service/"
  # Act
  test-capture env FORCE_USE_DOCKER=false DOCKER_IMAGE=service \
    make --no-print-directory -C "$TEST_TMP/tree" docker-lint
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-file-exists "$TEST_TMP/tree/infrastructure/images/service/Dockerfile.effective"

  return 0
}

function test-make-rejects-a-missing-docker-directory() {

  # Arrange
  prepare-service-docker
  # Act
  test-capture env DOCKER_IMAGE=service docker_dir=missing \
    make --no-print-directory -C "$TEST_TMP/tree/services/api" docker-bake-dockerfile
  # Assert
  assert-matches "$TEST_STATUS" '^[1-9][0-9]*$' "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "ERROR: Docker image directory not found: missing"
  assert-file-not-exists "$TEST_TMP/tree/services/api/Dockerfile.effective"

  return 0
}

function test-make-rejects-a-missing-root-image-directory() {

  # Arrange
  prepare-service-docker
  cp "$TEST_TMP/tree/services/api/Dockerfile" "$TEST_TMP/tree/Dockerfile"
  # Act
  test-capture env DOCKER_IMAGE=typo make --no-print-directory -C "$TEST_TMP/tree" docker-bake-dockerfile
  # Assert
  assert-matches "$TEST_STATUS" '^[1-9][0-9]*$' "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "ERROR: Docker image directory not found: infrastructure/images/typo"
  assert-contains "$TEST_STDERR" "dir=."
  assert-file-not-exists "$TEST_TMP/tree/Dockerfile.effective"

  return 0
}

function test-make-defaults-to-the-root-without-an-image-name() {

  # Arrange
  prepare-service-docker
  test-stub docker
  touch "$TEST_TMP/tree/Dockerfile.effective"
  # Act
  run-make _docker docker_fn=clean
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-file-not-exists "$TEST_TMP/tree/Dockerfile.effective"

  return 0
}

function test-make-reports-missing-mise-as-a-diagnostic() {

  # Arrange
  copy-core
  copy-docker-scripts
  test-isolate-path make
  # Act
  GITHUB_ACTIONS=true run-make _toolchain-check
  # Assert
  assert-matches "$TEST_STATUS" '^[1-9][0-9]*$' "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "::error::mise is not installed"

  return 0
}

function test-make-reports-untrusted-mise-config-as-a-diagnostic() {

  # Arrange
  copy-core
  copy-docker-scripts
  test-isolate-path make
  test-stub mise 'echo "mise.toml: untrusted"'
  # Act
  GITHUB_ACTIONS=true run-make _toolchain-check
  # Assert
  assert-matches "$TEST_STATUS" '^[1-9][0-9]*$' "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "::error::mise.toml is not trusted"

  return 0
}

function test-make-reports-a-missing-tool-name-as-a-diagnostic() {

  # Arrange
  copy-core
  copy-docker-scripts
  test-isolate-path make
  test-stub mise
  # Act
  GITHUB_ACTIONS=true run-make _toolchain-install-one name=
  # Assert
  assert-matches "$TEST_STATUS" '^[1-9][0-9]*$' "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "::error::name is required"

  return 0
}

function test-make-runs-shared-cleanup-at-the-repository-root() {

  # Arrange
  copy-core
  copy-docker-scripts
  write-service-makefile
  git init -q "$TEST_TMP/tree"
  echo '*.tmp' > "$TEST_TMP/tree/.gitignore"
  touch "$TEST_TMP/tree/root.tmp"
  test-isolate-path make
  test-stub docker
  # Act
  test-capture make --no-print-directory -C "$TEST_TMP/tree/services/api" clean
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-contains "$TEST_STDOUT" "Git cleanup covers the whole repository at $(cd "$TEST_TMP/tree" && pwd -P)"
  assert-contains "$TEST_STDOUT" "Would remove root.tmp"

  return 0
}

function test-make-keeps-the-service-directory-for-version-files() {

  # Arrange
  copy-core
  copy-docker-scripts
  write-service-makefile
  echo '1.2.3' > "$TEST_TMP/tree/services/api/VERSION"
  # Act
  test-capture make --no-print-directory -C "$TEST_TMP/tree/services/api" version-create-effective-file
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-file-exists "$TEST_TMP/tree/services/api/.version"
  assert-file-not-exists "$TEST_TMP/tree/.version"

  return 0
}

# ==============================================================================
# Helpers

# Copy the core Makefiles into the scratch tree, without any local module.
function copy-core() {

  mkdir -p "$TEST_TMP/tree/scripts/docker"
  cp "$TEST_REPO_ROOT/Makefile" "$TEST_TMP/tree/"
  cp "$TEST_REPO_ROOT/scripts/init.mk" "$TEST_TMP/tree/scripts/"
  cp "$TEST_REPO_ROOT/scripts/docker/docker.lib.mk" "$TEST_TMP/tree/scripts/docker/"

  return 0
}

# Copy the shell libraries that the Docker and version targets source.
function copy-docker-scripts() {

  mkdir -p "$TEST_TMP/tree/scripts/cicd"
  cp "$TEST_REPO_ROOT/scripts/docker/docker.lib.sh" "$TEST_TMP/tree/scripts/docker/"
  cp "$TEST_REPO_ROOT/scripts/cicd/github-actions.lib.sh" "$TEST_TMP/tree/scripts/cicd/"

  return 0
}

# Prepare a service image and the repository files used by Docker targets.
function prepare-service-docker() {

  copy-core
  copy-docker-scripts
  write-service-makefile
  cp "$TEST_REPO_ROOT/scripts/docker/dockerfile-linter.sh" "$TEST_TMP/tree/scripts/docker/"
  cp "$TEST_REPO_ROOT/scripts/docker/Dockerfile.metadata" "$TEST_TMP/tree/scripts/docker/"
  cp "$TEST_REPO_ROOT/scripts/docker/tests/mise.toml.test" "$TEST_TMP/tree/mise.toml"
  cp "$TEST_REPO_ROOT/scripts/docker/tests/Dockerfile" "$TEST_TMP/tree/services/api/Dockerfile"
  cp "$TEST_REPO_ROOT/scripts/docker/tests/VERSION" "$TEST_TMP/tree/services/api/VERSION"
  git init -q "$TEST_TMP/tree"
  git -C "$TEST_TMP/tree" -c user.name=Fixture -c user.email=fixture@example.invalid \
    -c core.hooksPath=/dev/null commit --allow-empty -q -m fixture
  test-isolate-path make
  test-stub hadolint

  return 0
}

# Add an Orders module that sets its own platform, a Billing module that does
# not, and a root 'images' target that builds both through recursive calls.
function prepare-platform-modules() {

  local module
  prepare-service-docker
  test-stub docker
  for module in orders billing; do
    mkdir -p "$TEST_TMP/tree/scripts/$module"
    # shellcheck disable=SC2016 # Make references, not shell ones
    printf '%s-image:\n\t$(MAKE) -C "$(CURDIR)" -f "$(MAKE_ENTRY_POINT)" docker-build DOCKER_IMAGE=%s docker_dir="$(REPOSITORY_ROOT_DIR)/services/api"\n' \
      "$module" "$module" > "$TEST_TMP/tree/scripts/$module/$module.mk"
  done
  printf 'orders-%%: DOCKER_PLATFORM := linux/arm64\n' >> "$TEST_TMP/tree/scripts/orders/orders.mk"
  # shellcheck disable=SC2016 # Make references, not shell ones
  printf '\nimages:\n\t%s\n' '$(MAKE) -C "$(CURDIR)" -f "$(MAKE_ENTRY_POINT)" orders-image billing-image' \
    >> "$TEST_TMP/tree/Makefile"

  return 0
}

# Print the platform of the recorded 'docker build' call for an image.
# Arguments:
#   $1=[image name]
function built-platform() {

  test-stub-calls docker | sed -n "/^build .*--tag $1:/s/.*--platform \([^ ]*\).*/\1/p"

  return 0
}

# Write a module file that defines one documented target.
# Arguments:
#   $1=[path relative to the scratch tree]
#   $2=[target name]
function write-module() {

  local file="$TEST_TMP/tree/$1" target="$2"
  mkdir -p "$(dirname "$file")"
  printf '%s: # Fixture target @Others\n\techo %s-ran\n' "$target" "$target" > "$file"

  return 0
}

# Write 'services/api/Makefile', which includes 'scripts/init.mk' relative to
# its own location, as a service entry point would, and names its modules.
# Arguments:
#   $@=[module paths relative to 'scripts/']
function write-service-makefile() {

  local module
  mkdir -p "$TEST_TMP/tree/services/api"
  # shellcheck disable=SC2016 # Make references, not shell ones
  printf '%s\n' \
    'SERVICE_DIR := $(dir $(lastword $(MAKEFILE_LIST)))' \
    'include $(SERVICE_DIR)../../scripts/init.mk' \
    > "$TEST_TMP/tree/services/api/Makefile"
  for module in "$@"; do
    # shellcheck disable=SC2016 # Make references, not shell ones
    printf '$(call include-once,%s)\n' "$module" >> "$TEST_TMP/tree/services/api/Makefile"
  done
  # shellcheck disable=SC2016 # Make references, not shell ones
  printf '%s\n' \
    '' \
    'service-where: # Print the recipe directory @Others' \
    $'\t@echo "where=$$(pwd -P)"' \
    '' \
    'service-only:' \
    $'\t@echo service-only-ran' \
    '' \
    'service-recurse: # Call this Makefile and a module recursively @Others' \
    $'\tcd / && $(MAKE) -C "$(CURDIR)" -f "$(MAKE_ENTRY_POINT)" service-only team-module' \
    >> "$TEST_TMP/tree/services/api/Makefile"

  return 0
}

# Run make in the scratch tree.
# Arguments:
#   $@=[make goals]
function run-make() {

  test-capture make --no-print-directory -C "$TEST_TMP/tree" "$@"

  return 0
}

# ==============================================================================

main "$@"
