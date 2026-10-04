#!/usr/bin/env bash

set -euo pipefail

# A set of Docker functions written in Bash.
#
# Usage:
#   $ source ./docker.lib.sh
#
# Arguments (provided as environment variables):
#   DOCKER_IMAGE=ghcr.io/org/repo      # Docker image name
#   DOCKER_TITLE="My Docker image"     # Docker image title
#   MISE_TOML=$project_dir/mise.toml   # Path to the mise config file
#   CONTAINER_CLI=docker               # Runtime used by docker-get-image-version-and-pull, default is 'docker'
#   CONTAINER_INFO_TIMEOUT=10          # Seconds to wait for '<runtime> info' before treating it as not operational

# ==============================================================================
# Functions to be used with custom images.

# Build Docker image.
# Arguments (provided as environment variables):
#   dir=[path to the Dockerfile to use, default is '.']
function docker-build() {

  local dir=${dir:-$PWD}
  local tag
  local version

  version-create-effective-file
  _create-effective-dockerfile

  tag=$(_get-effective-tag)

  docker build \
    --progress=plain \
    --platform linux/amd64 \
    --build-arg IMAGE="${DOCKER_IMAGE}" \
    --build-arg TITLE="${DOCKER_TITLE}" \
    --build-arg DESCRIPTION="${DOCKER_TITLE}" \
    --build-arg LICENCE=MIT \
    --build-arg GIT_URL="$(git config --get remote.origin.url)" \
    --build-arg GIT_BRANCH="$(_get-git-branch-name)" \
    --build-arg GIT_COMMIT_HASH="$(git rev-parse --short HEAD)" \
    --build-arg BUILD_DATE="$(date -u +"%Y-%m-%dT%H:%M:%S%z")" \
    --build-arg BUILD_VERSION="$(_get-effective-version)" \
    --tag "${tag}" \
    --rm \
    --file "${dir}/Dockerfile.effective" \
    . || return "$?"

  # Tag the image with all the stated versions, see the documentation for more details
  for version in $(_get-all-effective-versions) latest; do
    if [[ -n "$version" ]]; then
      docker tag "${tag}" "${DOCKER_IMAGE}:${version}" || return "$?"
    fi
  done

  return 0
}

# Create the Dockerfile.effective file to bake in version info
# Arguments (provided as environment variables):
#   dir=[path to the Dockerfile to use, default is '.']
function docker-bake-dockerfile() {

  local dir=${dir:-$PWD}

  version-create-effective-file || return "$?"
  _create-effective-dockerfile || return "$?"

  return 0
}

# Run hadolint over the generated Dockerfile.
# Arguments (provided as environment variables):
#  dir=[path to the image directory where the Dockerfile.effective is located, default is '.']
function docker-lint() {
  local dir=${dir:-$PWD}
  file=${dir}/Dockerfile.effective ./scripts/docker/dockerfile-linter.sh || return "$?"

  return 0
}

# Check test Docker image.
# Arguments (provided as environment variables):
#   args=[arguments to pass to Docker to run the container, default is none/empty]
#   cmd=[command to pass to the container for execution, default is none/empty]
#   dir=[path to the image directory where the Dockerfile is located, default is '.']
#   check=[output string to search for]
function docker-check-test() {

  local dir=${dir:-$PWD}

  # shellcheck disable=SC2086,SC2154
  docker run --rm --platform linux/amd64 \
    ${args:-} \
    "${DOCKER_IMAGE}:$(_get-effective-version)" 2>/dev/null \
    ${cmd:-} \
  | grep -q "${check}" && echo PASS || echo FAIL

  return 0
}

# Run Docker image.
# Arguments (provided as environment variables):
#   args=[arguments to pass to Docker to run the container, default is none/empty]
#   cmd=[command to pass to the container for execution, default is none/empty]
#   dir=[path to the image directory where the Dockerfile is located, default is '.']
function docker-run() {

  local dir=${dir:-$PWD}
  local tag
  tag=$(dir="$dir" _get-effective-tag)

  # shellcheck disable=SC2086
  docker run --rm --platform linux/amd64 \
    ${args:-} \
    "${tag}" \
    ${cmd:-} || return "$?"

  return 0
}

# Push Docker image.
# Arguments (provided as environment variables):
#   dir=[path to the image directory where the Dockerfile is located, default is '.']
function docker-push() {

  local dir=${dir:-$PWD}

  # Push all the image tags based on the stated versions, see the documentation for more details
  for version in $(dir="$dir" _get-all-effective-versions) latest; do
    docker push "${DOCKER_IMAGE}:${version}" || return "$?"
  done

  return 0
}

# Remove Docker resources.
# Arguments (provided as environment variables):
#   dir=[path to the image directory where the Dockerfile is located, default is '.']
function docker-clean() {

  local dir=${dir:-$PWD}

  for version in $(dir="$dir" _get-all-effective-versions) latest; do
    docker rmi "${DOCKER_IMAGE}:${version}" > /dev/null 2>&1 ||:
  done
  rm -f \
    "$dir/.version" \
    "$dir/Dockerfile.effective" \
    "$dir/Dockerfile.effective.dockerignore" || return "$?"

  return 0
}

# Create effective version from the VERSION file.
# Arguments (provided as environment variables):
#   dir=[path to the VERSION file to use, default is '.']
#   BUILD_DATETIME=[build date and time in the '%Y-%m-%dT%H:%M:%S%z' format generated by the CI/CD pipeline, default is current date and time]
function version-create-effective-file() {

  local dir=${dir:-$PWD}
  local version_file="$dir/VERSION"
  local build_datetime=${BUILD_DATETIME:-$(date -u +'%Y-%m-%dT%H:%M:%S%z')}

  if [[ -f "$version_file" ]]; then
    # shellcheck disable=SC2002
    cat "$version_file" | \
      sed "s/\(\${yyyy}\|\$yyyy\)/$(date --date="${build_datetime}" -u +"%Y")/g" | \
      sed "s/\(\${mm}\|\$mm\)/$(date --date="${build_datetime}" -u +"%m")/g" | \
      sed "s/\(\${dd}\|\$dd\)/$(date --date="${build_datetime}" -u +"%d")/g" | \
      sed "s/\(\${HH}\|\$HH\)/$(date --date="${build_datetime}" -u +"%H")/g" | \
      sed "s/\(\${MM}\|\$MM\)/$(date --date="${build_datetime}" -u +"%M")/g" | \
      sed "s/\(\${SS}\|\$SS\)/$(date --date="${build_datetime}" -u +"%S")/g" | \
      sed "s/\(\${hash}\|\$hash\)/$(git rev-parse --short HEAD)/g" \
    > "$dir/.version" || return "$?"
  fi

  return 0
}

# ==============================================================================
# Functions to be used with external images.

# Pull every image pinned in the 'mise.toml' file's '[_.docker]' table using the
# first operational runtime of Docker then Podman. Warn and return 0 when
# neither is installed and operational. Otherwise stop at the first failed pull
# and return its status, leaving the remaining images unpulled. Only this
# function falls back to Podman, the other functions and scripts call 'docker'.
function docker-pull-pinned-images() {

  local config_file="${MISE_TOML:=$(git rev-parse --show-toplevel)/mise.toml}"
  local image
  local container_cli=""
  local candidate
  local image_version
  local pull_status
  local probe_status
  local runtime_installed=false
  local runtime_states=""
  local timeout="${CONTAINER_INFO_TIMEOUT:-10}"
  local rerun="then run 'make docker-pull-pinned-images'"

  [[ -f "$config_file" ]] || return 0

  for candidate in docker podman; do
    if ! command -v "$candidate" > /dev/null 2>&1; then
      runtime_states+="${runtime_states:+; }${candidate}: not installed"
      continue
    fi
    runtime_installed=true
    echo "Checking ${candidate} (up to ${timeout}s)" >&2
    probe_status=0
    _container-runtime-is-operational "$candidate" || probe_status=$?
    if [[ $probe_status -eq 0 ]]; then
      container_cli="$candidate"
      break
    elif [[ $probe_status -eq 124 ]]; then
      runtime_states+="${runtime_states:+; }${candidate}: no response after ${timeout}s"
    else
      runtime_states+="${runtime_states:+; }${candidate}: installed, not running"
    fi
  done

  if [[ -z "$container_cli" ]]; then
    echo "WARN Docker/Podman image pull skipped (${runtime_states})" >&2
    if [[ "$runtime_installed" == true ]]; then
      echo "HINT Start Docker Desktop or run 'podman machine start', ${rerun}" >&2
    else
      echo "HINT Install Docker or Podman, see README.md, ${rerun}" >&2
    fi
    return 0
  fi

  while read -r image _; do
    [[ -n "$image" ]] || continue
    echo "Pulling ${image}"
    if image_version=$(CONTAINER_CLI="$container_cli" name="$image" docker-get-image-version-and-pull); then
      echo "OK ${image_version}"
    else
      pull_status=$?
      echo "ERROR Pulling ${image} with ${container_cli} failed with exit status ${pull_status}" >&2
      echo "HINT Check the network connection and registry login, ${rerun}" >&2
      return "$pull_status"
    fi
  done < <(_toml-table-entries "_.docker" "$config_file")

  return 0
}

# Retrieve the Docker image version from the 'mise.toml' file and pull the
# image if required. This function is to be used in conjunction with the
# external images and it prevents Docker from downloading an image each time it
# is used, since the digest is not stored locally for compressed images. To
# optimise, the solution is to pull the image using its digest and then tag it,
# checking this tag for existence for any subsequent use.
# Arguments (provided as environment variables):
#   name=[full name of the Docker image]
#   match_version=[regexp to match the version, for example if the same image is used with multiple tags, default is '.*']
#   CONTAINER_CLI=[container runtime command, default is 'docker']
# Return the status of the failed pull or tag command.
# shellcheck disable=SC2001,SC2154
function docker-get-image-version-and-pull() {

  # E.g. for the given entry '"ghcr.io/org/image" = "1.2.3@sha256:hash"' under
  # the '[_.docker]' table in the 'mise.toml' file, the following variables
  # will be set to:
  #   name="ghcr.io/org/image"
  #   version="1.2.3@sha256:hash"
  #   tag="1.2.3"
  #   digest="sha256:hash"

  # Get the image full version from the 'mise.toml' file's '[_.docker]' table,
  # match it by name and version regex, if given.
  local container_cli="${CONTAINER_CLI:-docker}"
  local version
  version="$(_get-docker-image-version)"

  # Split the image version into two, tag name and digest sha256.
  local tag
  tag="$(echo "$version" | sed 's/@.*$//')"
  local digest
  digest="$(echo "$version" | sed 's/^.*@//')"

  # Check if the image exists locally already.
  if ! "$container_cli" image inspect "${name}:${tag}" > /dev/null 2>&1; then
    if [[ "$digest" != "latest" ]]; then
      # Pull image by the digest sha256 and tag it.
      "$container_cli" pull \
        --platform linux/amd64 \
        "${name}@${digest}" \
      >&2 || return "$?"
      "$container_cli" tag "${name}@${digest}" "${name}:${tag}" || return "$?"
    else
      # Pull the latest image.
      "$container_cli" pull \
        --platform linux/amd64 \
        "${name}:latest" \
      >&2 || return "$?"
    fi
  fi

  echo "${name}:${version}"

  return 0
}

# ==============================================================================
# "Private" functions.

# Succeed when '<runtime> info' succeeds within CONTAINER_INFO_TIMEOUT seconds,
# return 124 on timeout, so a hung daemon socket cannot hang 'make config'.
# Arguments:
#   $1=[container runtime command]
function _container-runtime-is-operational() {

  local runtime="$1"
  local ticks_left=$(( ${CONTAINER_INFO_TIMEOUT:-10} * 10 ))
  local pid

  "$runtime" info > /dev/null 2>&1 &
  pid=$!
  while kill -0 "$pid" 2> /dev/null; do
    if (( ticks_left <= 0 )); then
      kill "$pid" 2> /dev/null || true
      { wait "$pid"; } 2> /dev/null || true
      return 124
    fi
    sleep 0.1
    ticks_left=$(( ticks_left - 1 ))
  done
  wait "$pid" || return "$?"

  return 0
}

# Print the version pinned for an image in the 'mise.toml' file's '[_.docker]'
# table, or 'latest' when there is no pin for exactly that image name.
# Arguments (provided as environment variables):
#   name=[full name of the Docker image]
#   match_version=[regexp to match the version, default is '.*']
function _get-docker-image-version() {

  local config_file="${MISE_TOML:=$(git rev-parse --show-toplevel)/mise.toml}"
  local version=""
  if [[ -f "$config_file" ]]; then
    version=$(_toml-table-entries "_.docker" "$config_file" \
      | awk -v name="$name" '$1 == name { print $2 }' \
      | grep "${match_version:-".*"}" \
      | head -n 1 || true)
  fi
  echo "${version:-latest}"

  return 0
}

# Print "key value" pairs for every single-line string entry of the given TOML
# table. Pass an empty table name for root-level entries before the first table
# header. Multi-line strings, arrays, inline tables, escaped strings, other
# value types and values with characters outside [A-Za-z0-9._:@/+~-] are
# skipped, never printed, so each output line is always safe to use as a sed
# substitution pair.
# Arguments:
#   $1=[dotted table header, e.g. 'tools' or '_.docker', or empty for root]
#   $2=[path to the TOML file]
function _toml-table-entries() {

  local table="[$1]"
  local file="$2"
  local rc=0

  [[ "$1" == "" ]] && table=""

  awk -v table="$table" -v dq='"' -v sq="'" '
    BEGIN { in_table = (table == "") }
    function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
    # Set value and after from a plain quoted string at the start of s, or return 0 if s does not start with one
    function quoted(s,  q, rest, end) {
      q = substr(s, 1, 1)
      if (q != dq && q != sq) return 0
      rest = substr(s, 2)
      end = index(rest, q)
      if (end == 0) return 0
      value = substr(rest, 1, end - 1)
      after = trim(substr(rest, end + 1))
      if (q == dq && index(value, "\\")) return 0
      return 1
    }
    # Return the index just past the string that opens at position i of s, honouring basic string escapes
    function skip_string(s, i,  q, n) {
      q = substr(s, i, 1)
      n = length(s)
      for (i++; i <= n; i++) {
        if (q == dq && substr(s, i, 1) == "\\") { i++; continue }
        if (substr(s, i, 1) == q) return i + 1
      }
      return n + 1
    }
    # Return the position of the first "=" outside quotes, or 0
    function eq_index(s,  i, c, n) {
      n = length(s)
      for (i = 1; i <= n;) {
        c = substr(s, i, 1)
        if (c == dq || c == sq) { i = skip_string(s, i); continue }
        if (c == "=") return i
        if (c == "#") return 0
        i++
      }
      return 0
    }
    # Track open multi-line strings (open_string) and bracket depth (depth) across s
    function scan(s,  i, c, n) {
      n = length(s)
      for (i = 1; i <= n;) {
        if (open_string != "") {
          if (open_string == dq dq dq && substr(s, i, 1) == "\\") { i += 2; continue }
          if (substr(s, i, 3) == open_string) {
            # TOML allows up to two extra quotes before the closing delimiter
            for (i += 3; i <= n && substr(s, i, 1) == substr(open_string, 1, 1); i++);
            open_string = ""
            continue
          }
          i++
          continue
        }
        c = substr(s, i, 1)
        if (substr(s, i, 3) == dq dq dq || substr(s, i, 3) == sq sq sq) { open_string = substr(s, i, 3); i += 3; continue }
        if (c == dq || c == sq) { i = skip_string(s, i); continue }
        if (c == "#") break
        if (c == "[" || c == "{") depth++
        if (c == "]" || c == "}") depth--
        i++
      }
      if (depth < 0) depth = 0
    }
    {
      line = $0
      sub(/\r$/, "", line)
      if (open_string != "" || depth > 0) {
        scan(line)
        next
      }
      line = trim(line)
      if (line == "" || substr(line, 1, 1) == "#") next
      if (substr(line, 1, 1) == "[") {
        header = line
        sub(/#.*$/, "", header)
        gsub(/[[:space:]]/, "", header)
        in_table = (header == table)
        next
      }
      eq = eq_index(line)
      if (eq == 0) next
      key = trim(substr(line, 1, eq - 1))
      rhs = trim(substr(line, eq + 1))
      # Multi-line strings, arrays and inline tables are never entries, even on one line
      scan(rhs)
      if (open_string != "" || depth > 0 || rhs ~ /^[[{]/ || substr(rhs, 1, 3) == dq dq dq || substr(rhs, 1, 3) == sq sq sq) next
      if (!in_table) next
      if (quoted(key)) {
        if (after != "" || value == "") next
        key = value
      } else if (key !~ /^[A-Za-z0-9_-]+$/) {
        next
      }
      if (!quoted(rhs) || value == "") next
      if (after != "" && substr(after, 1, 1) != "#") next
      if (key !~ /^[A-Za-z0-9._:@\/+~-]+$/ || value !~ /^[A-Za-z0-9._:@\/+~-]+$/) next
      print key " " value
    }
  ' "$file" || rc=$?

  return "$rc"
}

# Print the single value for a key in a TOML table, failing unless exactly one
# single-line string entry with that key exists.
# Arguments:
#   $1=[dotted table header, e.g. 'tools' or '_.docker', or empty for root]
#   $2=[entry key]
#   $3=[path to the TOML file]
function _toml-table-entry() {

  local table="$1"
  local key="$2"
  local file="$3"

  _toml-table-entries "$table" "$file" \
    | awk -v key="$key" '$1 == key { value = $2; count++ } END { if (count == 1) print value; else exit 1 }'

  return "$?"
}

# Create effective Dockerfile.
# Arguments (provided as environment variables):
#   dir=[path to the image directory where the Dockerfile is located, default is '.']
function _create-effective-dockerfile() {

  local dir=${dir:-$PWD}

  # If it exists, we need to copy the .dockerignore file to match the prefix of the
  # Dockerfile.effective file, otherwise docker won't use it.
  # See https://docs.docker.com/build/building/context/#filename-and-location
  # If using podman, this requires v5.0.0 or later.
  if [[ -f "${dir}/Dockerfile.dockerignore" ]]; then
    cp "${dir}/Dockerfile.dockerignore" "${dir}/Dockerfile.effective.dockerignore"
  fi
  cp "${dir}/Dockerfile" "${dir}/Dockerfile.effective" || return "$?"
  _pin-dockerfile-arg-versions || return "$?"
  _append-metadata || return "$?"

  return 0
}

# Pin the 'ARG <NAME>_VERSION=...' defaults that parameterise 'FROM image:${<NAME>_VERSION}'
# instructions to the versions in the 'mise.toml' file. Dockerfiles never contain a literal
# 'image:latest', which is what security scanners flag, so no ARG default is ever 'latest'
# either: it must be a real, valid version so the Dockerfile still builds without this
# substitution having run.
# Arguments (provided as environment variables):
#   dir=[path to the image directory where the Dockerfile is located, default is '.']
function _pin-dockerfile-arg-versions() {

  local dir=${dir:-$PWD}
  local config_file="${MISE_TOML:=$(git rev-parse --show-toplevel)/mise.toml}"
  local dockerfile="${dir}/Dockerfile.effective"
  local build_datetime=${BUILD_DATETIME:-$(date -u +'%Y-%m-%dT%H:%M:%S%z')}

  if [[ -f "$config_file" && -f "$dockerfile" ]]; then
    # First, list the '[_.docker]' entries to take precedence, then the '[tools]' entries as a fallback
    local entries
    entries=$(_toml-table-entries "_.docker" "$config_file"; _toml-table-entries "tools" "$config_file")
    awk '
      # First file (the mise.toml entries): record the first (highest-precedence) version seen per image name
      NR == FNR {
        if (NF == 2 && !($1 in pin)) pin[$1] = $2
        next
      }
      # Second file (the Dockerfile): find every ARG variable parameterising a pinned FROM image,
      # and which line declares that ARG, so its default can be rewritten in a single pass
      {
        lines[FNR] = $0
        line = $0
        if (line ~ /^FROM[[:space:]]/) {
          rest = line
          sub(/^FROM[[:space:]]+/, "", rest)
          sub(/^--platform=[^[:space:]]+[[:space:]]+/, "", rest)
          sub(/[[:space:]].*$/, "", rest)
          # Match the tag ARG separator, leaving any registry port in the image name
          colon = index(rest, ":${")
          if (colon > 0) {
            name = substr(rest, 1, colon - 1)
            tail = substr(rest, colon + 1)
            if (substr(tail, 1, 2) == "${") {
              brace = index(tail, "}")
              if (brace > 0 && name in pin) {
                var = substr(tail, 3, brace - 3)
                pin_for_arg[var] = pin[name]
              }
            }
          }
        } else if (line ~ /^ARG[[:space:]]+[A-Za-z_][A-Za-z0-9_]*=/) {
          rest = line
          sub(/^ARG[[:space:]]+/, "", rest)
          arg_line[substr(rest, 1, index(rest, "=") - 1)] = FNR
        }
      }
      END {
        for (var in pin_for_arg) {
          if (var == "" || !(var in arg_line)) continue
          lines[arg_line[var]] = "ARG " var "=" pin_for_arg[var]
        }
        for (i = 1; i <= FNR; i++) print lines[i]
      }
    ' <(printf '%s\n' "$entries") "$dockerfile" > "$dockerfile.tmp"
    mv "$dockerfile.tmp" "$dockerfile"
  fi

  if [[ -f "$dockerfile" ]]; then
    # shellcheck disable=SC2002
    cat "$dockerfile" | \
      sed "s/\(\${yyyy}\|\$yyyy\)/$(date --date="${build_datetime}" -u +"%Y")/g" | \
      sed "s/\(\${mm}\|\$mm\)/$(date --date="${build_datetime}" -u +"%m")/g" | \
      sed "s/\(\${dd}\|\$dd\)/$(date --date="${build_datetime}" -u +"%d")/g" | \
      sed "s/\(\${HH}\|\$HH\)/$(date --date="${build_datetime}" -u +"%H")/g" | \
      sed "s/\(\${MM}\|\$MM\)/$(date --date="${build_datetime}" -u +"%M")/g" | \
      sed "s/\(\${SS}\|\$SS\)/$(date --date="${build_datetime}" -u +"%S")/g" | \
      sed "s/\(\${hash}\|\$hash\)/$(git rev-parse --short HEAD)/g" \
    > "$dockerfile.tmp"
  mv "$dockerfile.tmp" "$dockerfile"
  fi

  # Do not ignore the issue if 'latest' is used in the effective image
  sed -Ei "/# hadolint ignore=DL3007$/d" "${dir}/Dockerfile.effective" || return "$?"

  return 0
}

# Append metadata to the end of Dockerfile.
# Arguments (provided as environment variables):
#   dir=[path to the image directory where the Dockerfile is located, default is '.']
function _append-metadata() {

  local dir=${dir:-$PWD}

  cat \
    "$dir/Dockerfile.effective" \
    "$(git rev-parse --show-toplevel)/scripts/docker/Dockerfile.metadata" \
  > "$dir/Dockerfile.effective.tmp" || return "$?"
  mv "$dir/Dockerfile.effective.tmp" "$dir/Dockerfile.effective" || return "$?"

  return 0
}

# Print top Docker image version.
# Arguments (provided as environment variables):
#   dir=[path to the image directory where the Dockerfile is located, default is '.']
function _get-effective-version() {

  local dir=${dir:-$PWD}

  head -n 1 "${dir}/.version" 2> /dev/null ||:

  return 0
}

# Print the effective tag for the image with the version. If you don't have a VERSION file
# then the tag will be just the image name.  Otherwise it will be the image name with the version.
# Arguments (provided as environment variables):
#   dir=[path to the image directory where the Dockerfile is located, default is '.']
function _get-effective-tag() {

  local tag=$DOCKER_IMAGE
  local version
  version=$(_get-effective-version)
  if [[ -n "$version" ]]; then
    tag="${tag}:${version}"
  fi
  echo "$tag"

  return 0
}

# Print all Docker image versions.
# Arguments (provided as environment variables):
#   dir=[path to the image directory where the Dockerfile is located, default is '.']
function _get-all-effective-versions() {

  local dir=${dir:-$PWD}

  cat "${dir}/.version" 2> /dev/null ||:

  return 0
}

# Print Git branch name. Check the GitHub variables first and then the local Git
# repo.
function _get-git-branch-name() {

  local branch_name
  branch_name=$(git rev-parse --abbrev-ref HEAD)

  if [[ -n "${GITHUB_HEAD_REF:-}" ]]; then
    branch_name=$GITHUB_HEAD_REF
  elif [[ -n "${GITHUB_REF:-}" ]]; then
    # shellcheck disable=SC2001
    branch_name=$(echo "$GITHUB_REF" | sed "s#refs/heads/##")
  fi

  echo "$branch_name"

  return 0
}
