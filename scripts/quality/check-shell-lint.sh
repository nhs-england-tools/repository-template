#!/usr/bin/env bash

set -euo pipefail

# ShellCheck command wrapper. It will run ShellCheck natively if it is
# installed, otherwise it will run it in a Docker container.
#
# Usage:
#   $ [options] ./check-shell-lint.sh
#
# Arguments (provided as environment variables):
#   check=file              # Lint the single shell script given by 'file', default mode
#   check=all               # Lint tracked existing '*.sh' files in one ShellCheck call or Docker container, ignoring 'file'
#   file=shellscript        # Path to the shell script to lint, relative to the project's top-level directory, default is itself
#   FORCE_USE_DOCKER=true   # If set to true the command is run in a Docker container, default is 'false'
#   VERBOSE=true            # Show all the executed commands, default is 'false'
#
# Exit codes:
#   0 - All files passed, or no tracked files were found
#   1 - ShellCheck findings, unsupported check mode, or local setup failure
#   Other non-zero statuses from Git, Bash setup, ShellCheck, image pulls, or Docker are propagated.
#
# Notes:
#   1) In 'all' mode, only tracked existing '*.sh' files are linted.
#   2) Untracked scripts, including ignored ones, are not linted.
#   3) In 'all' mode, sourced tracked libraries are ShellCheck inputs too. Their assignments can affect diagnostics compared with single-file mode.

# ==============================================================================

# Lint the shell script natively or in Docker.
function main() {

  cd "$(git rev-parse --show-toplevel)"

  local check_mode=${check:-file}
  local rc=0
  if [[ "$check_mode" == all ]]; then
    local -a files=()
    collect-tracked-shell-files files || return "$?"

    [[ ${#files[@]} -eq 0 ]] && return 0
    if command -v shellcheck > /dev/null 2>&1 && ! is-arg-true "${FORCE_USE_DOCKER:-false}"; then
      run-shellcheck-natively-all "${files[@]}" || rc=$?
    else
      run-shellcheck-in-docker-all "${files[@]}" || rc=$?
    fi
  elif [[ "$check_mode" == file ]]; then
    [[ -z "${file:-}" ]] && echo "WARNING: 'file' variable not set, defaulting to itself"
    local file=${file:-scripts/quality/check-shell-lint.sh}
    if command -v shellcheck > /dev/null 2>&1 && ! is-arg-true "${FORCE_USE_DOCKER:-false}"; then
      file="$file" run-shellcheck-natively || rc=$?
    else
      file="$file" run-shellcheck-in-docker || rc=$?
    fi
  else
    echo "ERROR: unsupported check mode '$check_mode'. Use check=file or check=all." >&2
    return 1
  fi

  return "$rc"
}

# Collect tracked shell scripts that still exist in the working tree.
# Arguments:
#   $1=[name reference of the output array]
function collect-tracked-shell-files() {

  local -n tracked_files="$1" || return "$?"
  local path previous_path='' rc tracked_list_file
  tracked_list_file="$(mktemp)" || { echo "ERROR: cannot create a temporary file for tracked shell scripts" >&2; return 1; }
  # Git pathspec mode variables can change the meaning of the '*.sh' pattern.
  if env -u GIT_GLOB_PATHSPECS -u GIT_NOGLOB_PATHSPECS \
    -u GIT_LITERAL_PATHSPECS -u GIT_ICASE_PATHSPECS \
    git ls-files -z -- '*.sh' > "$tracked_list_file"; then
    :
  else
    rc=$?
    rm -f "$tracked_list_file"
    return "$rc"
  fi
  while IFS= read -r -d '' path; do
    # Git can list a conflicted index path once for each stage.
    if [[ "$path" != "$previous_path" && -f "$path" ]]; then
      tracked_files+=("$path")
    fi
    previous_path="$path"
  done < "$tracked_list_file" || {
    rc=$?
    rm -f "$tracked_list_file"
    return "$rc"
  }
  rm -f "$tracked_list_file"

  return 0
}

# Run ShellCheck natively.
# Arguments (provided as environment variables):
#   file=[path to the shell script to lint, relative to the project's top-level directory]
function run-shellcheck-natively() {

  local rc=0
  # shellcheck disable=SC2001
  shellcheck "$(echo "$file" | sed "s#$PWD#.#")" || rc=$?

  return "$rc"
}

# Run ShellCheck natively over tracked files.
# Arguments:
#   $@=[tracked shell-script paths, relative to the repository root]
function run-shellcheck-natively-all() {

  local rc=0
  shellcheck -- "$@" || rc=$?

  return "$rc"
}

# Run ShellCheck in a Docker container.
# Arguments (provided as environment variables):
#   file=[path to the shell script to lint, relative to the project's top-level directory]
function run-shellcheck-in-docker() {

  # shellcheck disable=SC1091
  source ./scripts/docker/docker.lib.sh

  local image
  image=$(name=koalaman/shellcheck docker-get-image-version-and-pull) || return "$?"
  local rc=0
  # shellcheck disable=SC2001
  docker run --rm --platform linux/amd64 \
    --volume "$PWD:/workdir" \
    --workdir /workdir \
    "$image" \
      "/workdir/$(echo "$file" | sed "s#$PWD#.#")" || rc=$?

  return "$rc"
}

# Run ShellCheck in one Docker container over tracked files.
# Arguments:
#   $@=[tracked shell-script paths, relative to the repository root]
function run-shellcheck-in-docker-all() {

  # shellcheck disable=SC1091
  source ./scripts/docker/docker.lib.sh

  local image
  image=$(name=koalaman/shellcheck docker-get-image-version-and-pull) || return "$?"
  local -a container_files=()
  local file
  for file in "$@"; do
    container_files+=("/workdir/$file")
  done
  local rc=0
  docker run --rm --platform linux/amd64 \
    --volume "$PWD:/workdir" \
    --workdir /workdir \
    "$image" \
    -- "${container_files[@]}" || rc=$?

  return "$rc"
}

# ==============================================================================

# Check whether the supplied argument represents a true boolean value.
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
