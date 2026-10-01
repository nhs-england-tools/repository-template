#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2317,SC2329

set -euo pipefail

# Unit test suite for the Docker library functions. Every test that can reach
# the docker command stubs it, so the suite needs no Docker daemon, and every
# test writes only into its own scratch directory.
#
# Usage:
#   $ ./scripts/docker/tests/docker-lib.test.sh
#
# Arguments (provided as environment variables):
#   VERBOSE=true  # Show all the executed commands, default is 'false'

# ==============================================================================

readonly DOCKER_TABLE_HEADER='[_.docker]'
readonly FIXTURE_BUILD_DATETIME='2023-09-04T15:46:34+0000'
readonly EXIT_STATUS_LABEL='exit status'

function main() {

  cd "$(git rev-parse --show-toplevel)"
  source ./scripts/tests/test.lib.sh
  source ./scripts/docker/docker.lib.sh

  # The caller's options must not reach the functions under test
  unset -v args cmd check dir name match_version MISE_TOML BUILD_DATETIME GITHUB_HEAD_REF GITHUB_REF

  DOCKER_IMAGE=repository-template/docker-test
  DOCKER_TITLE="Repository Template Docker Test"
  FIXTURE_MISE_TOML="$TEST_REPO_ROOT/scripts/docker/tests/mise.toml.test"
  DIGEST_A="sha256:$(printf 'a%.0s' {1..64})"
  DIGEST_B="sha256:$(printf 'b%.0s' {1..64})"

  test-run-suite \
    test-pin-dockerfile-arg-versions-uses-docker-table-pin \
    test-pin-dockerfile-arg-versions-matches-exact-image-name \
    test-pin-dockerfile-arg-versions-handles-registry-port \
    test-pin-dockerfile-arg-versions-pins-every-arg-for-image \
    test-docker-toml-table-entries \
    test-docker-get-image-version \
    test-pin-dockerfile-arg-versions-falls-back-to-tools-table \
    test-pin-dockerfile-arg-versions-handles-platform-flag-and-stage-alias \
    test-pin-dockerfile-arg-versions-leaves-unpinned-args-alone \
    test-pin-dockerfile-arg-versions-substitutes-date-tokens \
    test-pin-dockerfile-arg-versions-drops-latest-ignore-comments \
    test-version-create-effective-file-writes-exact-lines \
    test-version-create-effective-file-substitutes-time-tokens \
    test-version-create-effective-file-skips-missing-version-file \
    test-get-effective-tag-with-and-without-version-file \
    test-get-git-branch-name-prefers-github-variables \
    test-docker-get-image-version-and-pull-pulls-by-digest-and-tags \
    test-docker-get-image-version-and-pull-skips-pull-when-tag-exists \
    test-docker-get-image-version-and-pull-pulls-latest-without-pin \
    test-docker-get-image-version-and-pull-selects-by-match-version \
    test-docker-build-passes-metadata-and-tags-every-version \
    test-docker-bake-dockerfile-creates-effective-files \
    test-docker-run-passes-args-command-and-tag \
    test-docker-check-test-reports-pass-and-fail \
    test-docker-push-pushes-every-version-and-latest \
    test-docker-clean-removes-images-and-files-in-dir \
    test-docker-lint-runs-hadolint-on-effective-dockerfile

  return 0
}

# ==============================================================================

function test-pin-dockerfile-arg-versions-uses-docker-table-pin() {

  # Arrange
  MISE_TOML="$FIXTURE_MISE_TOML"
  export BUILD_DATETIME="$FIXTURE_BUILD_DATETIME"
  cp "$TEST_REPO_ROOT/scripts/docker/tests/Dockerfile" "$TEST_TMP/Dockerfile.effective"
  # Act
  dir="$TEST_TMP" _pin-dockerfile-arg-versions
  # Assert
  assert-matches "$(grep '^ARG PYTHON_VERSION=' "$TEST_TMP/Dockerfile.effective")" \
    '^ARG PYTHON_VERSION=.*-alpine.*@sha256:.*' "ARG PYTHON_VERSION is pinned"

  return 0
}

function test-pin-dockerfile-arg-versions-matches-exact-image-name() {

  # Arrange
  MISE_TOML="$FIXTURE_MISE_TOML"
  export BUILD_DATETIME="$FIXTURE_BUILD_DATETIME"
  cat > "$TEST_TMP/Dockerfile.effective" << 'EOF'
ARG PYTHON_VERSION=3.11.0
FROM python:${PYTHON_VERSION}

ARG CIMG_PYTHON_VERSION=3.10.0
FROM cimg/python:${CIMG_PYTHON_VERSION} AS other
EOF
  # Act
  dir="$TEST_TMP" _pin-dockerfile-arg-versions
  # Assert
  assert-matches "$(grep '^ARG PYTHON_VERSION=' "$TEST_TMP/Dockerfile.effective")" \
    '^ARG PYTHON_VERSION=3\.11\.4-alpine3\.18@sha256:' "python pin"
  assert-matches "$(grep '^ARG CIMG_PYTHON_VERSION=' "$TEST_TMP/Dockerfile.effective")" \
    '^ARG CIMG_PYTHON_VERSION=3\.12\.0@sha256:' "cimg/python pin"

  return 0
}

function test-pin-dockerfile-arg-versions-handles-registry-port() {

  # Arrange
  MISE_TOML="$TEST_TMP/mise.toml"
  export BUILD_DATETIME="$FIXTURE_BUILD_DATETIME"
  printf '%s\n' "$DOCKER_TABLE_HEADER" '"registry.example:5000/team/image" = "2.0.0"' > "$MISE_TOML"
  cat > "$TEST_TMP/Dockerfile.effective" << 'EOF'
ARG IMAGE_VERSION=1.0.0
FROM --platform=linux/amd64 registry.example:5000/team/image:${IMAGE_VERSION} AS base
ARG OTHER_VERSION=1.0.0
FROM registry.example/team/image:${OTHER_VERSION} AS other
EOF
  cat > "$TEST_TMP/Dockerfile.expected" << 'EOF'
ARG IMAGE_VERSION=2.0.0
FROM --platform=linux/amd64 registry.example:5000/team/image:${IMAGE_VERSION} AS base
ARG OTHER_VERSION=1.0.0
FROM registry.example/team/image:${OTHER_VERSION} AS other
EOF
  # Act
  dir="$TEST_TMP" _pin-dockerfile-arg-versions
  # Assert
  assert-files-identical "$TEST_TMP/Dockerfile.expected" "$TEST_TMP/Dockerfile.effective"

  return 0
}

function test-pin-dockerfile-arg-versions-pins-every-arg-for-image() {

  # Arrange
  MISE_TOML="$TEST_TMP/mise.toml"
  export BUILD_DATETIME="$FIXTURE_BUILD_DATETIME"
  printf '%s\n' "$DOCKER_TABLE_HEADER" 'alpine = "3.20.0"' > "$MISE_TOML"
  cat > "$TEST_TMP/Dockerfile.effective" << 'EOF'
ARG BUILD_VERSION=3.18.0
ARG RUNTIME_VERSION=3.19.0
FROM alpine:${BUILD_VERSION} AS build
FROM alpine:${RUNTIME_VERSION} AS runtime
EOF
  cat > "$TEST_TMP/Dockerfile.expected" << 'EOF'
ARG BUILD_VERSION=3.20.0
ARG RUNTIME_VERSION=3.20.0
FROM alpine:${BUILD_VERSION} AS build
FROM alpine:${RUNTIME_VERSION} AS runtime
EOF
  # Act
  dir="$TEST_TMP" _pin-dockerfile-arg-versions
  # Assert
  assert-files-identical "$TEST_TMP/Dockerfile.expected" "$TEST_TMP/Dockerfile.effective"

  return 0
}

function test-docker-toml-table-entries() {

  # Arrange
  local expected_docker expected_tools actual_docker actual_tools
  MISE_TOML="$FIXTURE_MISE_TOML"
  expected_docker="$(printf '%s\n' \
    "python 3.11.4-alpine3.18@sha256:0135ae6442d1269379860b361760ad2cf6ab7c403d21935a8015b48d5bf78a86" \
    "cimg/python 3.12.0@sha256:1111111111111111111111111111111111111111111111111111111111111111" \
    "ghcr.io/org/single-quoted 1.0.0@sha256:2222222222222222222222222222222222222222222222222222222222222222")"
  expected_tools="python 3.14.7"
  # Act
  actual_docker="$(_toml-table-entries "_.docker" "$MISE_TOML")"
  actual_tools="$(_toml-table-entries "tools" "$MISE_TOML")"
  # Assert
  assert-equal "$expected_docker" "$actual_docker" "[_.docker] entries"
  assert-equal "$expected_tools" "$actual_tools" "[tools] entries"

  return 0
}

function test-docker-get-image-version() {

  # Arrange
  MISE_TOML="$FIXTURE_MISE_TOML"
  unset match_version
  local exact suffix quoted missing filtered
  # Act
  exact="$(name=python _get-docker-image-version)"
  suffix="$(name=cimg/python _get-docker-image-version)"
  quoted="$(name=ghcr.io/org/single-quoted _get-docker-image-version)"
  missing="$(name=org/not-pinned _get-docker-image-version)"
  filtered="$(name=python match_version=".*-rt.*" _get-docker-image-version)"
  # Assert
  assert-equal "3.11.4-alpine3.18@sha256:0135ae6442d1269379860b361760ad2cf6ab7c403d21935a8015b48d5bf78a86" "$exact" "exact name"
  assert-equal "3.12.0@sha256:1111111111111111111111111111111111111111111111111111111111111111" "$suffix" "name with a matching suffix"
  assert-equal "1.0.0@sha256:2222222222222222222222222222222222222222222222222222222222222222" "$quoted" "single-quoted entry"
  assert-equal "latest" "$missing" "name without a pin"
  assert-equal "latest" "$filtered" "pin filtered out by match_version"

  return 0
}

function test-pin-dockerfile-arg-versions-falls-back-to-tools-table() {

  # Arrange
  MISE_TOML="$TEST_TMP/mise.toml"
  export BUILD_DATETIME="$FIXTURE_BUILD_DATETIME"
  printf '%s\n' '[tools]' 'ruby = "3.3.0"' '' "$DOCKER_TABLE_HEADER" > "$MISE_TOML"
  cat > "$TEST_TMP/Dockerfile.effective" << 'EOF'
ARG RUBY_VERSION=3.2.0
FROM ruby:${RUBY_VERSION}
EOF
  # Act
  dir="$TEST_TMP" _pin-dockerfile-arg-versions
  # Assert
  assert-file-has-line "$TEST_TMP/Dockerfile.effective" "ARG RUBY_VERSION=3.3.0"

  return 0
}

function test-pin-dockerfile-arg-versions-handles-platform-flag-and-stage-alias() {

  # Arrange
  MISE_TOML="$FIXTURE_MISE_TOML"
  export BUILD_DATETIME="$FIXTURE_BUILD_DATETIME"
  cat > "$TEST_TMP/Dockerfile.effective" << 'EOF'
ARG PYTHON_VERSION=3.11.0
FROM --platform=linux/amd64 python:${PYTHON_VERSION} AS base
EOF
  # Act
  dir="$TEST_TMP" _pin-dockerfile-arg-versions
  # Assert
  assert-file-has-line "$TEST_TMP/Dockerfile.effective" \
    "ARG PYTHON_VERSION=3.11.4-alpine3.18@sha256:0135ae6442d1269379860b361760ad2cf6ab7c403d21935a8015b48d5bf78a86"
  # shellcheck disable=SC2016
  assert-file-has-line "$TEST_TMP/Dockerfile.effective" \
    'FROM --platform=linux/amd64 python:${PYTHON_VERSION} AS base'

  return 0
}

function test-pin-dockerfile-arg-versions-leaves-unpinned-args-alone() {

  # Arrange
  MISE_TOML="$FIXTURE_MISE_TOML"
  export BUILD_DATETIME="$FIXTURE_BUILD_DATETIME"
  cat > "$TEST_TMP/Dockerfile.input" << 'EOF'
ARG NODE_IMAGE_VERSION=20.0.0
FROM example.org/unpinned:${NODE_IMAGE_VERSION}
EOF
  cp "$TEST_TMP/Dockerfile.input" "$TEST_TMP/Dockerfile.effective"
  # Act
  dir="$TEST_TMP" _pin-dockerfile-arg-versions
  # Assert
  assert-files-identical "$TEST_TMP/Dockerfile.input" "$TEST_TMP/Dockerfile.effective"

  return 0
}

function test-pin-dockerfile-arg-versions-substitutes-date-tokens() {

  # Arrange
  MISE_TOML="$FIXTURE_MISE_TOML"
  export BUILD_DATETIME="$FIXTURE_BUILD_DATETIME"
  cat > "$TEST_TMP/Dockerfile.effective" << 'EOF'
FROM example.org/unpinned:1.0.0
LABEL built="${yyyy}-${mm}-${dd}T${HH}:${MM}:${SS}"
EOF
  # Act
  dir="$TEST_TMP" _pin-dockerfile-arg-versions
  # Assert
  assert-file-has-line "$TEST_TMP/Dockerfile.effective" 'LABEL built="2023-09-04T15:46:34"'

  return 0
}

function test-pin-dockerfile-arg-versions-drops-latest-ignore-comments() {

  # Arrange
  MISE_TOML="$FIXTURE_MISE_TOML"
  export BUILD_DATETIME="$FIXTURE_BUILD_DATETIME"
  printf '%s\n' \
    'ARG TOOL_VERSION=1.0.0' \
    '# hadolint ignore=DL3007' \
    'FROM example.org/tool:latest' \
    'RUN echo done' \
    > "$TEST_TMP/Dockerfile.effective"
  printf '%s\n' \
    'ARG TOOL_VERSION=1.0.0' \
    'FROM example.org/tool:latest' \
    'RUN echo done' \
    > "$TEST_TMP/Dockerfile.expected"
  # Act
  dir="$TEST_TMP" _pin-dockerfile-arg-versions
  # Assert
  assert-files-identical "$TEST_TMP/Dockerfile.expected" "$TEST_TMP/Dockerfile.effective"

  return 0
}

function test-version-create-effective-file-writes-exact-lines() {

  # Arrange
  local commit
  commit="$(git rev-parse --short HEAD)"
  use-empty-mise-toml
  export BUILD_DATETIME="$FIXTURE_BUILD_DATETIME"
  cp "$TEST_REPO_ROOT/scripts/docker/tests/VERSION" "$TEST_TMP/VERSION"
  printf '%s\n' "20230904-$commit" "2023.09.04-$commit" "somme-name-yyyyeah" > "$TEST_TMP/expected.version"
  # Act
  dir="$TEST_TMP" version-create-effective-file
  # Assert
  assert-files-identical "$TEST_TMP/expected.version" "$TEST_TMP/.version"

  return 0
}

function test-version-create-effective-file-substitutes-time-tokens() {

  # Arrange
  use-empty-mise-toml
  export BUILD_DATETIME="$FIXTURE_BUILD_DATETIME"
  cat > "$TEST_TMP/VERSION" << 'EOF'
${HH}${MM}${SS}
$HH.$MM.$SS
EOF
  printf '%s\n' 154634 15.46.34 > "$TEST_TMP/expected.version"
  # Act
  dir="$TEST_TMP" version-create-effective-file
  # Assert
  assert-files-identical "$TEST_TMP/expected.version" "$TEST_TMP/.version"

  return 0
}

function test-version-create-effective-file-skips-missing-version-file() {

  # Arrange
  use-empty-mise-toml
  export BUILD_DATETIME="$FIXTURE_BUILD_DATETIME"
  # Act
  dir="$TEST_TMP" test-capture version-create-effective-file
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-file-not-exists "$TEST_TMP/.version"

  return 0
}

function test-get-effective-tag-with-and-without-version-file() {

  # Arrange
  local without with
  use-empty-mise-toml
  # Act
  without="$(dir="$TEST_TMP" _get-effective-tag)"
  printf '%s\n' 1.2.3 latest-ish > "$TEST_TMP/.version"
  with="$(dir="$TEST_TMP" _get-effective-tag)"
  # Assert
  assert-equal "repository-template/docker-test" "$without" "tag without a .version file"
  assert-equal "repository-template/docker-test:1.2.3" "$with" "tag with a .version file"

  return 0
}

function test-get-git-branch-name-prefers-github-variables() {

  # Arrange
  local head_ref ref local_branch
  use-empty-mise-toml
  unset GITHUB_HEAD_REF GITHUB_REF
  # Act
  head_ref="$(GITHUB_HEAD_REF=feature/x GITHUB_REF=refs/heads/other _get-git-branch-name)"
  ref="$(GITHUB_REF=refs/heads/release/1 _get-git-branch-name)"
  local_branch="$(_get-git-branch-name)"
  # Assert
  assert-equal "feature/x" "$head_ref" "GITHUB_HEAD_REF wins"
  assert-equal "release/1" "$ref" "GITHUB_REF without the refs/heads/ prefix"
  assert-equal "$(git rev-parse --abbrev-ref HEAD)" "$local_branch" "local git branch"

  return 0
}

function test-docker-get-image-version-and-pull-pulls-by-digest-and-tags() {

  # Arrange
  write-image-pin
  unset match_version
  test-isolate-path
  test-stub docker
  # Act
  name=ghcr.io/org/image test-capture docker-get-image-version-and-pull
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "ghcr.io/org/image:1.2.3@$DIGEST_A" "$TEST_STDOUT" "stdout"
  assert-equal "$(printf '%s\n' \
    "pull --platform linux/amd64 ghcr.io/org/image@$DIGEST_A" \
    "tag ghcr.io/org/image@$DIGEST_A ghcr.io/org/image:1.2.3")" \
    "$(docker-pull-and-tag-calls)" "pull and tag calls"

  return 0
}

function test-docker-get-image-version-and-pull-skips-pull-when-tag-exists() {

  # Arrange
  write-image-pin
  unset match_version
  test-isolate-path
  # shellcheck disable=SC2016
  test-stub docker 'if [[ "${1:-} ${2:-}" == "image ls" ]]; then echo ghcr.io/org/image:1.2.3; fi'
  # Act
  name=ghcr.io/org/image test-capture docker-get-image-version-and-pull
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "ghcr.io/org/image:1.2.3@$DIGEST_A" "$TEST_STDOUT" "stdout"
  assert-equal "" "$(docker-pull-and-tag-calls)" "pull and tag calls"

  return 0
}

function test-docker-get-image-version-and-pull-pulls-latest-without-pin() {

  # Arrange
  write-image-pin
  unset match_version
  test-isolate-path
  test-stub docker
  # Act
  name=ghcr.io/org/unpinned test-capture docker-get-image-version-and-pull
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "ghcr.io/org/unpinned:latest" "$TEST_STDOUT" "stdout"
  assert-equal "pull --platform linux/amd64 ghcr.io/org/unpinned:latest" \
    "$(docker-pull-and-tag-calls)" "pull and tag calls"

  return 0
}

function test-docker-get-image-version-and-pull-selects-by-match-version() {

  # Arrange
  local rt_stdout rt_calls
  unset match_version
  MISE_TOML="$TEST_TMP/mise.toml"
  cat > "$MISE_TOML" << EOF
[_.docker]
"ghcr.io/org/rt" = "1.2.3-rt@$DIGEST_B"
"ghcr.io/org/image" = "1.2.3@$DIGEST_A"
EOF
  test-isolate-path
  test-stub docker
  # Act
  name=ghcr.io/org/rt match_version='.*-rt.*' test-capture docker-get-image-version-and-pull
  rt_stdout="$TEST_STDOUT"
  rt_calls="$(docker-pull-and-tag-calls)"
  : > "$STUB_DIR/docker.calls"
  name=ghcr.io/org/image match_version='.*-rt.*' test-capture docker-get-image-version-and-pull
  # Assert
  assert-equal "ghcr.io/org/rt:1.2.3-rt@$DIGEST_B" "$rt_stdout" "stdout for the matching pin"
  assert-equal "$(printf '%s\n' \
    "pull --platform linux/amd64 ghcr.io/org/rt@$DIGEST_B" \
    "tag ghcr.io/org/rt@$DIGEST_B ghcr.io/org/rt:1.2.3-rt")" \
    "$rt_calls" "pull and tag calls for the matching pin"
  assert-equal "ghcr.io/org/image:latest" "$TEST_STDOUT" "stdout for the filtered-out pin"
  assert-equal "pull --platform linux/amd64 ghcr.io/org/image:latest" \
    "$(docker-pull-and-tag-calls)" "pull and tag calls for the filtered-out pin"

  return 0
}

function test-docker-build-passes-metadata-and-tags-every-version() {

  # Arrange
  local commit build build_count image=repository-template/docker-test
  commit="$(git rev-parse --short HEAD)"
  copy-image-fixtures
  MISE_TOML="$FIXTURE_MISE_TOML"
  export BUILD_DATETIME="$FIXTURE_BUILD_DATETIME"
  test-isolate-path
  test-stub docker
  # Act
  dir="$TEST_TMP" test-capture docker-build
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  build_count="$(test-stub-calls docker | awk '/^build / { n++ } END { print n + 0 }')"
  assert-equal 1 "$build_count" "number of build calls"
  # Spaces around the line and each needle make every needle match whole arguments.
  build=" $(test-stub-calls docker | grep '^build ' || true) "
  assert-contains "$build" " --build-arg IMAGE=$image "
  assert-contains "$build" " --build-arg TITLE=Repository\\ Template\\ Docker\\ Test "
  assert-contains "$build" " --build-arg BUILD_VERSION=20230904-$commit "
  assert-contains "$build" " --tag $image:20230904-$commit "
  assert-contains "$build" " --file $(printf '%q' "$TEST_TMP/Dockerfile.effective") "
  assert-equal "$(printf '%s\n' \
    "tag $image:20230904-$commit $image:20230904-$commit" \
    "tag $image:20230904-$commit $image:2023.09.04-$commit" \
    "tag $image:20230904-$commit $image:somme-name-yyyyeah" \
    "tag $image:20230904-$commit $image:latest")" \
    "$(test-stub-calls docker | grep '^tag ' || true)" "tag calls"
  assert-effective-dockerfile-is-pinned-with-metadata "$TEST_TMP/Dockerfile.effective"

  return 0
}

function test-docker-bake-dockerfile-creates-effective-files() {

  # Arrange
  copy-image-fixtures
  echo "*.tmp" > "$TEST_TMP/Dockerfile.dockerignore"
  MISE_TOML="$FIXTURE_MISE_TOML"
  export BUILD_DATETIME="$FIXTURE_BUILD_DATETIME"
  test-isolate-path
  test-stub docker
  # Act
  dir="$TEST_TMP" test-capture docker-bake-dockerfile
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-file-exists "$TEST_TMP/.version"
  assert-file-exists "$TEST_TMP/Dockerfile.effective"
  assert-file-exists "$TEST_TMP/Dockerfile.effective.dockerignore"
  assert-effective-dockerfile-is-pinned-with-metadata "$TEST_TMP/Dockerfile.effective"
  assert-stub-not-called docker

  return 0
}

function test-docker-run-passes-args-command-and-tag() {

  # Arrange
  use-empty-mise-toml
  echo 1.2.3 > "$TEST_TMP/.version"
  test-isolate-path
  test-stub docker
  # Act
  args="--env A=1" cmd="python --version" dir="$TEST_TMP" test-capture docker-run
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "run --rm --platform linux/amd64 --env A=1 repository-template/docker-test:1.2.3 python --version" \
    "$(test-stub-calls docker)" "docker calls"

  return 0
}

function test-docker-check-test-reports-pass-and-fail() {

  # Arrange
  local found
  use-empty-mise-toml
  test-isolate-path
  # shellcheck disable=SC2016
  test-stub docker 'if [[ "${1:-}" == run ]]; then echo "Python 3.11.4"; fi'
  # Act
  check=Python dir="$TEST_TMP" test-capture docker-check-test
  found="$TEST_STDOUT"
  check=Ruby dir="$TEST_TMP" test-capture docker-check-test
  # Assert
  assert-equal PASS "$found" "output when the check string is present"
  assert-equal FAIL "$TEST_STDOUT" "output when the check string is absent"

  return 0
}

function test-docker-push-pushes-every-version-and-latest() {

  # Arrange
  use-empty-mise-toml
  printf '%s\n' 1.2.3 1.2 > "$TEST_TMP/.version"
  test-isolate-path
  test-stub docker
  # Act
  dir="$TEST_TMP" test-capture docker-push
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "$(printf '%s\n' \
    "push repository-template/docker-test:1.2.3" \
    "push repository-template/docker-test:1.2" \
    "push repository-template/docker-test:latest")" \
    "$(test-stub-calls docker)" "push calls"

  return 0
}

function test-docker-clean-removes-images-and-files-in-dir() {

  # Arrange
  use-empty-mise-toml
  mkdir "$TEST_TMP/elsewhere" "$TEST_TMP/image"
  cd "$TEST_TMP/elsewhere"
  echo 1.2.3 > "$TEST_TMP/image/.version"
  touch "$TEST_TMP/image/Dockerfile.effective" "$TEST_TMP/image/Dockerfile.effective.dockerignore"
  test-isolate-path
  # shellcheck disable=SC2016
  test-stub docker 'if [[ "${1:-}" == rmi ]]; then exit 1; fi'
  # Act
  dir="$TEST_TMP/image" test-capture docker-clean
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-stub-called docker "rmi repository-template/docker-test:1.2.3"
  assert-stub-called docker "rmi repository-template/docker-test:latest"
  assert-file-not-exists "$TEST_TMP/image/.version"
  assert-file-not-exists "$TEST_TMP/image/Dockerfile.effective"
  assert-file-not-exists "$TEST_TMP/image/Dockerfile.effective.dockerignore"

  return 0
}

function test-docker-lint-runs-hadolint-on-effective-dockerfile() {

  # Arrange
  use-empty-mise-toml
  unset FORCE_USE_DOCKER
  test-isolate-path
  test-stub hadolint
  test-stub docker
  # Act
  dir="$TEST_TMP" test-capture docker-lint
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "--config scripts/config/hadolint.yaml $(printf '%q' "$TEST_TMP/Dockerfile.effective")" \
    "$(test-stub-calls hadolint)" "hadolint calls"
  assert-stub-not-called docker

  return 0
}

# ==============================================================================
# Helpers

# Copy the test image's Dockerfile and VERSION files into "$TEST_TMP".
function copy-image-fixtures() {

  cp "$TEST_REPO_ROOT/scripts/docker/tests/Dockerfile" "$TEST_REPO_ROOT/scripts/docker/tests/VERSION" "$TEST_TMP/"

  return 0
}

# Write an empty "$TEST_TMP/mise.toml" and point MISE_TOML at it.
function use-empty-mise-toml() {

  MISE_TOML="$TEST_TMP/mise.toml"
  : > "$MISE_TOML"

  return 0
}

# Write "$TEST_TMP/mise.toml" pinning 'ghcr.io/org/image' to '1.2.3@$DIGEST_A'
# and point MISE_TOML at it.
function write-image-pin() {

  MISE_TOML="$TEST_TMP/mise.toml"
  printf '%s\n' "$DOCKER_TABLE_HEADER" "\"ghcr.io/org/image\" = \"1.2.3@$DIGEST_A\"" > "$MISE_TOML"

  return 0
}

# Print the recorded docker 'pull' and 'tag' calls, one per line.
function docker-pull-and-tag-calls() {

  test-stub-calls docker | grep -E '^(pull|tag) ' || true

  return 0
}

# Fail unless the effective Dockerfile pins ARG PYTHON_VERSION from the fixture
# and ends with the exact bytes of scripts/docker/Dockerfile.metadata.
# Arguments:
#   $1=[path to the effective Dockerfile]
function assert-effective-dockerfile-is-pinned-with-metadata() {

  local file="$1" metadata="$TEST_REPO_ROOT/scripts/docker/Dockerfile.metadata" size
  assert-file-has-line "$file" \
    "ARG PYTHON_VERSION=3.11.4-alpine3.18@sha256:0135ae6442d1269379860b361760ad2cf6ab7c403d21935a8015b48d5bf78a86"
  size="$(wc -c < "$metadata")"
  tail -c "$((size))" "$file" > "$TEST_TMP/effective-tail"
  assert-files-identical "$metadata" "$TEST_TMP/effective-tail"

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
