#!/bin/bash
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
# in 'docker-lib.test.sh', so this suite never pulls anything but the base
# image pinned in 'mise.toml.test'.
#
# Usage:
#   $ ./scripts/docker/tests/docker.test.sh
#
# Arguments (provided as environment variables):
#   VERBOSE=true  # Show all the executed commands, default is 'false'

# ==============================================================================

function main() {

  cd "$(git rev-parse --show-toplevel)"
  source ./scripts/tests/test.lib.sh
  source ./scripts/docker/docker.lib.sh
  cd ./scripts/docker/tests

  # The caller's options must not reach the functions under test
  unset -v args dir
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
    test-docker-teardown-warns-when-test-images-cannot-be-removed

  return 0
}

# ==============================================================================

# Name this run's images, check the daemon is reachable and build the image
# the tests share from a copy of the image files.
function test-suite-setup() {

  local rc suffix
  suffix="$(basename "$SUITE_TMP" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9')"
  export DOCKER_IMAGE="repository-template/docker-test-$suffix"
  CLEAN_IMAGE="repository-template/docker-test-clean-$suffix"
  if ! docker info > /dev/null 2>&1; then
    echo "ERROR: the Docker daemon is not reachable, start Docker and rerun" >&2
    return 1
  fi
  mkdir "$SUITE_TMP/image"
  cp Dockerfile VERSION "$SUITE_TMP/image/"
  set +e
  ( set -e; dir="$SUITE_TMP/image" docker-build ) > "$SUITE_TMP/build.log" 2>&1
  rc=$?
  set -e
  if [[ $rc -ne 0 ]]; then
    cat "$SUITE_TMP/build.log" >&2
    echo "ERROR: docker-build failed in the suite setup" >&2
    return 1
  fi

  return 0
}

# Remove this run's test images, never failing.
function test-suite-teardown() {

  remove-test-images || true

  return 0
}

# Remove every local tag of this run's test images, ignoring anything already
# gone and only warning when an image cannot be removed.
function remove-test-images() {

  local tags
  tags="$(docker images --format '{{.Repository}}:{{.Tag}}' 2> /dev/null \
    | awk -v a="$DOCKER_IMAGE" -v b="$CLEAN_IMAGE" -F: '$1 == a || $1 == b' || true)"
  if [[ -n "$tags" ]]; then
    # shellcheck disable=SC2086
    docker rmi $tags > /dev/null 2>&1 ||
      echo "WARNING: could not remove test images: ${tags//$'\n'/ }" >&2
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
  local version revision expected labels
  version="$(head -n 1 "$SUITE_TMP/image/.version")"
  revision="$(git rev-parse --short HEAD)"
  expected="$(printf '%s\n' "$version" "$revision" "$DOCKER_TITLE")"
  # Act
  labels="$(docker image inspect --format \
    '{{ index .Config.Labels "org.opencontainers.image.version" }}
{{ index .Config.Labels "org.opencontainers.image.revision" }}
{{ index .Config.Labels "org.opencontainers.image.title" }}' \
    "$DOCKER_IMAGE:$version")"
  # Assert
  assert-equal "$expected" "$labels" "version, revision and title labels"

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
  cmd="python --version" dir="$SUITE_TMP/image" test-capture docker-run
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

function test-docker-teardown-warns-when-test-images-cannot-be-removed() {

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
  assert-equal 0 "$TEST_STATUS" "exit status when docker rmi fails"
  assert-equal "WARNING: could not remove test images: $DOCKER_IMAGE:1.0 $CLEAN_IMAGE:latest" \
    "$TEST_STDERR" "stderr when docker rmi fails"
  assert-stub-called docker "rmi $DOCKER_IMAGE:1.0 $CLEAN_IMAGE:latest"

  return 0
}

# ==============================================================================

function is-arg-true() {

  if [[ "$1" =~ ^(true|yes|y|on|1|TRUE|YES|Y|ON)$ ]]; then
    return 0
  else
    return 1
  fi
}

# ==============================================================================

is-arg-true "${VERBOSE:-false}" && set -x

main "$@"

exit 0
