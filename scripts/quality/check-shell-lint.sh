#!/usr/bin/env bash

set -euo pipefail

# Lint shell scripts with ShellCheck. It runs ShellCheck natively when
# installed, otherwise in a Docker container. It also fails any full-line
# comment longer than 80 characters in a shell script or a '*.mk' file, except
# a line with a URL and the shebang.
#
# Usage:
#   $ [options] ./scripts/quality/check-shell-lint.sh
#
# Options:
#   check={file,all}       # Check mode, default is 'file'
#   file=path              # Script to lint in 'file' mode, default is itself
#   FORCE_USE_DOCKER=true  # Run in a Docker container, default is 'false'
#   VERBOSE=true           # Show all the executed commands, default is 'false'
#
# Exit codes:
#   0 - All files passed, or no tracked files were found
#   1 - ShellCheck or comment length findings, an unsupported check mode, or a
#       local setup failure
#   Other - Non-zero statuses from Git, Bash, ShellCheck, image pulls or Docker
#           are passed through, even when comment length findings are also
#           reported
#
# Notes:
#   1) 'file' mode lints one script, or checks only the comments of a '*.mk'
#      file. 'all' mode lints every existing tracked '*.sh' file, see note 4,
#      and ignores 'file'.
#   2) Untracked scripts, including ignored ones, are never linted.
#   3) In 'all' mode, sourced tracked libraries are ShellCheck inputs too. Their
#      assignments can change diagnostics compared with 'file' mode.
#   4) 'all' mode first runs ShellCheck in parallel, quietly, natively or in one
#      container each, over groups of each script and the tracked scripts it
#      names, directly or not. When every group passes, so does one call over
#      all the files, since ShellCheck follows only sourced files that are
#      inputs. Otherwise that one call runs and gives the report and exit
#      status.
#   5) The comment length check needs no ShellCheck or Docker. It runs in both
#      modes and counts bytes in the C locale, so a non-ASCII character counts
#      as more than one. 'all' mode also checks every existing tracked '*.mk'
#      file, which ShellCheck never sees. Unreadable files are left to
#      ShellCheck to report.
#   6) A line counts as a comment when its first non-blank character is '#',
#      including such lines in heredocs and embedded awk or Python code. A
#      comment line containing '://' is exempt, so a long URL never fails.

# ==============================================================================

# Lint the shell script natively or in Docker.
function main() {

  cd "$(git rev-parse --show-toplevel)"

  local check_mode=${check:-file}
  local rc=0
  if [[ "$check_mode" == all ]]; then
    local -a files=() make_files=() tracked=()
    local tracked_path
    collect-tracked-files tracked || return "$?"
    for tracked_path in "${tracked[@]}"; do
      if [[ "$tracked_path" == *.mk ]]; then
        make_files+=("$tracked_path")
      else
        files+=("$tracked_path")
      fi
    done

    [[ ${#files[@]} -eq 0 && ${#make_files[@]} -eq 0 ]] && return 0
    if [[ ${#files[@]} -gt 0 ]]; then
      if command -v shellcheck > /dev/null 2>&1 && ! is-arg-true "${FORCE_USE_DOCKER:-false}"; then
        run-shellcheck-natively-all "${files[@]}" || rc=$?
      else
        run-shellcheck-in-docker-all "${files[@]}" || rc=$?
      fi
    fi
    check-comment-length "${files[@]}" "${make_files[@]}" || [[ $rc -ne 0 ]] || rc=1
  elif [[ "$check_mode" == file ]]; then
    [[ -z "${file:-}" ]] && echo "WARNING: 'file' variable not set, defaulting to itself"
    local file=${file:-scripts/quality/check-shell-lint.sh}
    if [[ "$file" == *.mk ]]; then
      :
    elif command -v shellcheck > /dev/null 2>&1 && ! is-arg-true "${FORCE_USE_DOCKER:-false}"; then
      file="$file" run-shellcheck-natively || rc=$?
    else
      file="$file" run-shellcheck-in-docker || rc=$?
    fi
    # shellcheck disable=SC2001
    check-comment-length "$(echo "$file" | sed "s#$PWD#.#")" || [[ $rc -ne 0 ]] || rc=1
  else
    echo "ERROR: unsupported check mode '$check_mode'. Use check=file or check=all." >&2
    return 1
  fi

  return "$rc"
}

# Collect tracked shell scripts and '*.mk' files that still exist in the
# working tree.
# Arguments:
#   $1=[name reference of the output array]
function collect-tracked-files() {

  local -n tracked_files="$1" || return "$?"
  local path previous_path='' rc tracked_list_file
  tracked_list_file="$(mktemp)" || { echo "ERROR: cannot create a temporary file for tracked shell scripts" >&2; return 1; }
  # Git pathspec mode variables can change the meaning of the patterns.
  if env -u GIT_GLOB_PATHSPECS -u GIT_NOGLOB_PATHSPECS \
    -u GIT_LITERAL_PATHSPECS -u GIT_ICASE_PATHSPECS \
    git ls-files -z -- '*.sh' '*.mk' > "$tracked_list_file"; then
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

# Print each full-line comment over the length limit, and fail if there is one.
# Arguments:
#   $@=[shell-script and Make file paths, relative to the repository root]
function check-comment-length() {

  local -a paths=()
  local path rc=0
  for path in "$@"; do
    [[ -r "$path" ]] || continue
    # Without a '/', awk would read a name such as 'a=b.sh' as an assignment
    [[ "$path" == /* ]] || path="./$path"
    paths+=("$path")
  done
  # awk would read stdin without any file
  [[ ${#paths[@]} -gt 0 ]] || return 0
  LC_ALL=C awk -v max=80 '
    FNR == 1 && /^#!/ { next }
    /^[[:space:]]*#/ && length($0) > max && $0 !~ /:\/\// {
      name = FILENAME
      sub(/^\.\//, "", name)
      printf "%s:%d: comment is %d characters, the limit is %d\n", name, FNR, length($0), max
      found = 1
    }
    END { exit found }
  ' "${paths[@]}" >&2 || rc=1

  return "$rc"
}

# Run ShellCheck natively.
# Arguments (provided as environment variables):
#   file=[path to the shell script to lint, relative to the repository root]
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
  run-shellcheck-all shellcheck "$@" || rc=$?

  return "$rc"
}

# Run ShellCheck over tracked files in parallel groups first, then in one call
# over all of them if a group fails, to give the report and exit status.
# Arguments:
#   $1=[command that takes ShellCheck options, then '--' and the paths]
#   $@=[tracked shell-script paths, relative to the repository root]
function run-shellcheck-all() {

  local runner="$1"
  shift
  run-shellcheck-groups-in-parallel "$runner" "$@" && return 0
  local rc=0
  "$runner" -- "$@" || rc=$?

  return "$rc"
}

# Run quiet ShellCheck calls in parallel, one for each group of scripts. The
# calls stop starting after the first failure. It fails unless the groups cover
# every path.
# Arguments:
#   $1=[command that takes ShellCheck options, then '--' and the paths]
#   $@=[tracked shell-script paths, relative to the repository root]
function run-shellcheck-groups-in-parallel() {

  local runner="$1"
  shift
  local -a files=("$@") inputs=() pids=() covered=()
  local group k pid limit rc=0
  limit="$(getconf _NPROCESSORS_ONLN 2> /dev/null || echo 4)"
  while read -r group; do
    ((rc == 0)) || break
    [[ "$group" =~ ^[0-9]+( [0-9]+)*$ ]] || { rc=1; break; }
    inputs=()
    for k in $group; do
      ((10#$k < $#)) || { rc=1; break 2; }
      covered[10#$k]=1
      inputs+=("${files[10#$k]}")
    done
    if ((${#pids[@]} >= limit)); then
      wait "${pids[0]}" || rc=1
      pids=("${pids[@]:1}")
    fi
    "$runner" -f quiet -- "${inputs[@]}" > /dev/null 2>&1 &
    pids+=("$!")
  done < <(print-shell-script-groups "$@")
  for pid in "${pids[@]}"; do
    wait "$pid" || rc=1
  done
  # A failed group plan leaves paths out, which must not pass
  ((${#covered[@]} == $#)) || rc=1

  return "$rc"
}

# Print groups of indexes into the paths, one group per line, largest first. A
# group holds a script and every script it names, directly or not, in path
# order. A script already in a printed group starts no group of its own.
# Arguments:
#   $@=[shell-script paths]
function print-shell-script-groups() {

  local -a files=("$@") named=() groups=() sizes=() queue=() seen=() grouped=()
  local -A index=()
  local count=$# i j k path
  for ((i = 0; i < count; i++)); do
    index["${files[i]}"]=$i
  done
  for ((j = 0; j < count; j++)); do
    # grep would split a name with a newline into several patterns
    [[ "${files[j]}" == *$'\n'* ]] && continue
    while IFS= read -r -d '' path; do
      i="${index["$path"]:-}"
      [[ -n "$i" && "$i" -ne "$j" ]] && named[i]+=" $j"
    done < <(grep -lF --null -e "${files[j]##*/}" -- "${files[@]}" 2> /dev/null)
  done
  for ((i = 0; i < count; i++)); do
    seen=([i]=1)
    queue=("$i")
    while ((${#queue[@]} > 0)); do
      k=${queue[0]}
      queue=("${queue[@]:1}")
      for j in ${named[k]:-}; do
        [[ -n "${seen[j]:-}" ]] || { seen[j]=1; queue+=("$j"); }
      done
    done
    # Indexed array keys expand in ascending order, which is path order
    groups[i]="${!seen[*]}"
    sizes[i]=${#seen[@]}
  done
  while read -r _ i; do
    [[ -n "${grouped[i]:-}" ]] && continue
    for k in ${groups[i]}; do
      grouped[k]=1
    done
    echo "${groups[i]}"
  done < <(for ((i = 0; i < count; i++)); do
    echo "${sizes[i]} $i"
  done | sort -k1,1nr -k2,2n)

  return 0
}

# Run ShellCheck in a Docker container.
# Arguments (provided as environment variables):
#   file=[path to the shell script to lint, relative to the repository root]
function run-shellcheck-in-docker() {

  # shellcheck disable=SC1091
  source ./scripts/docker/docker.lib.sh

  local image
  image=$(name=koalaman/shellcheck docker-get-image-version-and-pull) || return "$?"
  local rc=0
  # shellcheck disable=SC2001
  docker run --rm --platform linux/amd64 \
    --network none \
    --volume "$PWD:/workdir:ro" \
    --workdir /workdir \
    "$image" \
      "/workdir/$(echo "$file" | sed "s#$PWD#.#")" || rc=$?

  return "$rc"
}

# Run ShellCheck in Docker over tracked files.
# Arguments:
#   $@=[tracked shell-script paths, relative to the repository root]
function run-shellcheck-in-docker-all() {

  # shellcheck disable=SC1091
  source ./scripts/docker/docker.lib.sh

  local image
  image=$(name=koalaman/shellcheck docker-get-image-version-and-pull) || return "$?"
  local rc=0
  run-shellcheck-all run-shellcheck-container "$@" || rc=$?

  return "$rc"
}

# Run ShellCheck in one Docker container.
# Arguments (provided as environment variables):
#   image=[pulled ShellCheck image]
# Arguments:
#   $@=[ShellCheck options, then '--' and the shell-script paths, relative to
#     the repository root]
# shellcheck disable=SC2329
function run-shellcheck-container() {

  local -a args=()
  while [[ "$1" != -- ]]; do
    args+=("$1")
    shift
  done
  shift
  args+=(--)
  local file
  for file in "$@"; do
    args+=("/workdir/$file")
  done
  local rc=0
  docker run --rm --platform linux/amd64 \
    --network none \
    --volume "$PWD:/workdir:ro" \
    --workdir /workdir \
    "$image" \
    "${args[@]}" || rc=$?

  return "$rc"
}

# ==============================================================================

# Check whether the supplied argument represents a true boolean value.
# Arguments:
#   $1=[value to evaluate]
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
