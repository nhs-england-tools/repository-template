#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2317,SC2329

set -euo pipefail

# Integration test suite for the Docker library functions that need a real
# Docker daemon. The tests share one image built in the suite setup from a copy
# of this directory's Dockerfile and VERSION in "$SUITE_TMP/image", and only
# read it. 'test-docker-clean-removes-every-tag-and-generated-file' builds and
# removes its own image under a separate name, so test order does not matter.
# Both image names end with a suffix unique to the run, and setup and teardown
# remove only this run's tags, so concurrent runs sharing the Docker daemon,
# such as the Stop hook in parallel worktrees, never collide. Nothing is
# written inside the repository. A run killed with SIGKILL leaves its tags.
# The former test that pulled a real, unpinned image over the network is
# replaced by deterministic stub tests of 'docker-get-image-version-and-pull'
# in 'docker.lib.test.sh', so this suite never pulls anything but the base
# image pinned in 'mise.toml.test'.
#
# Usage:
#   $ ./scripts/docker/tests/docker.test.sh
#
# Arguments (provided as environment variables):
#   VERBOSE=true  # Show all the executed commands, default is 'false'

# ==============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/../../tests/test.lib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../docker.lib.sh"

function main() {

  cd "$(git rev-parse --show-toplevel)"
  cd ./scripts/docker/tests

  # The caller's options must not reach the functions under test
  unset -v args cmd dir docker_dir GITHUB_ACTIONS
  export DOCKER_TITLE="Repository Template Docker Test"
  export BUILD_DATETIME="2023-09-04T15:46:34+0000"
  export MISE_TOML="$PWD/mise.toml.test"
  PINNED_PYTHON="3.11.4-alpine3.18@sha256:0135ae6442d1269379860b361760ad2cf6ab7c403d21935a8015b48d5bf78a86"

  test-run-suite \
    test-docker-build-tags-every-version-on-one-image \
    test-docker-build-sets-oci-labels \
    test-docker-build-pins-base-image-from-mise-toml \
    test-docker-run-executes-the-command \
    test-docker-check-test-passes-and-fails \
    test-docker-clean-removes-every-tag-and-generated-file \
    test-docker-teardown-fails-when-test-images-cannot-be-removed

  return 0
}

# ==============================================================================

# Name this run's images, check the daemon is reachable and build the image
# the tests share from a copy of the image files.
function test-suite-setup() {

  local rc suffix
  DOCKER_TEST_BUILD_ATTEMPTED=false
  suffix="$(basename "$SUITE_TMP" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9')"
  export DOCKER_IMAGE="repository-template/docker-test-$suffix"
  CLEAN_IMAGE="repository-template/docker-test-clean-$suffix"
  if ! command -v docker > /dev/null 2>&1; then
    echo "PREREQUISITE: the Docker CLI is not on PATH. Diagnose with: command -v docker. Docker tests did not run, so verification is unknown." >&2
    return 77
  fi

  if ! docker info > /dev/null 2>&1; then
    echo "PREREQUISITE: the Docker daemon is not reachable. Diagnose with: docker info. Docker tests did not run, so verification is unknown." >&2
    return 77
  fi
  mkdir "$SUITE_TMP/image"
  cp Dockerfile VERSION "$SUITE_TMP/image/"
  DOCKER_TEST_BUILD_ATTEMPTED=true
  set +e
  ( set -e; dir="$SUITE_TMP/image" docker-build ) > "$SUITE_TMP/build.log" 2>&1
  rc=$?
  set -e
  if [[ $rc -ne 0 ]]; then
    cat "$SUITE_TMP/build.log" >&2
    print-diagnostic error "docker-build failed in the suite setup (exit $rc). Tests did not run. Review the build output above, then rerun: bash scripts/docker/tests/docker.test.sh"
    return 1
  fi

  return 0
}

# Remove this run's test images only when a build could have created them.
function test-suite-teardown() {

  [[ "${DOCKER_TEST_BUILD_ATTEMPTED:-false}" == true ]] || return 0
  remove-test-images || return "$?"

  return 0
}

# Remove every local tag of this run's test images and report cleanup failures.
function remove-test-images() {

  local images tag removal_command message
  local -a tags=()
  images="$(docker images --format '{{.Repository}}:{{.Tag}}')" || {
    printf -v message 'cannot enumerate test images for %s and %s. Cleanup is incomplete and test images may remain. Diagnose with: docker images --format %q' "$DOCKER_IMAGE" "$CLEAN_IMAGE" '{{.Repository}}:{{.Tag}}'
    print-diagnostic error "$message"
    return 1
  }
  while IFS= read -r tag; do
    if [[ "${tag%:*}" == "$DOCKER_IMAGE" || "${tag%:*}" == "$CLEAN_IMAGE" ]]; then
      tags+=("$tag")
    fi
  done <<< "$images"
  if [[ ${#tags[@]} -gt 0 ]]; then
    docker rmi "${tags[@]}" > /dev/null || {
      printf -v removal_command ' %q' "${tags[@]}"
      print-diagnostic error "cannot remove test images. Cleanup is incomplete and test images may remain. Diagnose with: docker rmi$removal_command"
      return 1
    }
  fi

  return 0
}

# ==============================================================================

function test-docker-build-tags-every-version-on-one-image() {

  # Arrange
  local refs=() version
  while IFS= read -r version; do
    refs+=("$DOCKER_IMAGE:$version")
  done < "$SUITE_TMP/image/.version"
  refs+=("$DOCKER_IMAGE:latest")
  # Act
  test-capture docker image inspect --format '{{.Id}}' "${refs[@]}"
  # Assert
  assert-equal 4 "${#refs[@]}" "number of tags, the three .version lines plus latest"
  assert-equal "" "$TEST_STDERR" "errors inspecting the tags"
  assert-equal 0 "$TEST_STATUS" "every tag exists"
  assert-equal 4 "$(awk 'END { print NR }' <<< "$TEST_STDOUT")" "number of image IDs"
  assert-equal 1 "$(sort -u <<< "$TEST_STDOUT" | awk 'END { print NR }')" "number of distinct image IDs"

  return 0
}

function test-docker-build-sets-oci-labels() {

  # Arrange
  local version revision base_digest expected labels created
  version="$(head -n 1 "$SUITE_TMP/image/.version")"
  revision="$(git rev-parse --short HEAD)"
  base_digest="${PINNED_PYTHON##*@}"
  expected="$(printf '%s\n' \
    "$version" \
    "$revision" \
    "$DOCKER_TITLE" \
    "docker.io/library/python:3.11.4-alpine3.18" \
    "$base_digest")"
  # Act
  labels="$(docker image inspect --format \
    '{{ index .Config.Labels "org.opencontainers.image.version" }}
{{ index .Config.Labels "org.opencontainers.image.revision" }}
{{ index .Config.Labels "org.opencontainers.image.title" }}
{{ index .Config.Labels "org.opencontainers.image.base.name" }}
{{ index .Config.Labels "org.opencontainers.image.base.digest" }}' \
    "$DOCKER_IMAGE:$version")"
  created="$(docker image inspect --format \
    '{{ index .Config.Labels "org.opencontainers.image.created" }}' \
    "$DOCKER_IMAGE:$version")"
  # Assert
  assert-equal "$expected" "$labels" "version, revision and title labels"
  assert-matches "$created" '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' \
    "RFC 3339 created label"

  return 0
}

function test-docker-build-pins-base-image-from-mise-toml() {

  # Arrange
  local dockerfile="$SUITE_TMP/image/Dockerfile.effective"
  # Act
  # The suite setup ran docker-build, which generated the file
  # Assert
  assert-file-exists "$dockerfile"
  assert-file-has-line "$dockerfile" "ARG PYTHON_VERSION=$PINNED_PYTHON"
  assert-file-has-line "$dockerfile" "USER nobody"

  return 0
}

function test-docker-run-executes-the-command() {

  # Arrange
  # Act
  test-capture env -u MAKEFLAGS -u MAKELEVEL -u GNUMAKEFLAGS -u MAKEFILES \
    make --no-print-directory -C "$TEST_REPO_ROOT" docker-run \
    DOCKER_IMAGE="$DOCKER_IMAGE" \
    dir="$SUITE_TMP/image" \
    cmd="python --version"
  # Assert
  assert-equal 0 "$TEST_STATUS" "docker-run exit status"
  assert-matches "$TEST_STDOUT" '^Python 3\.11\.4$' "docker-run output"

  return 0
}

function test-docker-check-test-passes-and-fails() {

  # Arrange
  local pass_output fail_output
  # Act
  cmd="python --version" check="Python 3.11.4" dir="$SUITE_TMP/image" test-capture docker-check-test
  pass_output="$TEST_STDOUT"
  cmd="python --version" check="Ruby" dir="$SUITE_TMP/image" test-capture docker-check-test
  fail_output="$TEST_STDOUT"
  # Assert
  assert-equal PASS "$pass_output" "output when the check matches"
  assert-equal FAIL "$fail_output" "output when the check does not match"

  return 0
}

function test-docker-clean-removes-every-tag-and-generated-file() {

  # Arrange
  local expected_tags tags_before tags_after
  cp Dockerfile VERSION "$TEST_TMP/"
  touch "$TEST_TMP/Dockerfile.dockerignore"
  DOCKER_IMAGE="$CLEAN_IMAGE"
  dir="$TEST_TMP" docker-build
  expected_tags="$( (cat "$TEST_TMP/.version"; echo latest) | LC_ALL=C sort)"
  tags_before="$(docker images --format '{{.Tag}}' "$DOCKER_IMAGE" | LC_ALL=C sort)"
  assert-equal "$expected_tags" "$tags_before" "tags of $DOCKER_IMAGE before docker-clean"
  assert-file-exists "$TEST_TMP/Dockerfile.effective.dockerignore"
  # Act
  dir="$TEST_TMP" docker-clean
  # Assert
  tags_after="$(docker images --format '{{.Tag}}' "$DOCKER_IMAGE")"
  assert-equal "" "$tags_after" "tags of $DOCKER_IMAGE after docker-clean"
  assert-file-not-exists "$TEST_TMP/.version"
  assert-file-not-exists "$TEST_TMP/Dockerfile.effective"
  assert-file-not-exists "$TEST_TMP/Dockerfile.effective.dockerignore"

  return 0
}

function test-docker-teardown-fails-when-test-images-cannot-be-removed() {

  # Arrange
  local removed_stderr
  local images="if [[ \"\${1:-}\" == images ]]; then printf '%s\n' '$DOCKER_IMAGE:1.0' '$CLEAN_IMAGE:latest' other/image:1"
  test-stub docker "$images; fi"
  # Act
  test-capture test-suite-teardown
  removed_stderr="$TEST_STDERR"
  test-stub docker "$images; elif [[ \"\${1:-}\" == rmi ]]; then exit 1; fi"
  test-capture test-suite-teardown
  # Assert
  assert-equal "" "$removed_stderr" "stderr when docker rmi succeeds"
  assert-equal 1 "$TEST_STATUS" "exit status when docker rmi fails"
  assert-contains "$TEST_STDERR" "ERROR: cannot remove test images"
  assert-contains "$TEST_STDERR" "Cleanup is incomplete"
  assert-contains "$TEST_STDERR" "docker rmi $DOCKER_IMAGE:1.0 $CLEAN_IMAGE:latest"
  assert-stub-called docker "rmi $DOCKER_IMAGE:1.0 $CLEAN_IMAGE:latest"

  return 0
}

# ==============================================================================

function is-arg-true() {

  local value="$1"
  if [[ "$value" =~ ^(true|yes|y|on|1|TRUE|YES|Y|ON)$ ]]; then
    return 0
  else
    return 1
  fi
}

# ==============================================================================

is-arg-true "${VERBOSE:-false}" && set -x

main "$@"

exit 0
