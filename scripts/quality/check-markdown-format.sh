#!/usr/bin/env bash

set -euo pipefail

# Check that Markdown files follow the markdownlint rules and that YAML
# frontmatter is followed by a blank line. It runs markdownlint natively when
# installed, otherwise in a Docker container.
#
# Usage:
#   $ [options] ./scripts/quality/check-markdown-format.sh
#
# Options:
#   check={all,staged-changes,working-tree-changes,branch}  # Check mode, default is 'working-tree-changes'
#   BRANCH_NAME=other-branch-than-main                      # Branch to compare with, default is 'origin/main'
#   FORCE_USE_DOCKER=true                                   # If set to true the command is run in a Docker container, default is 'false'
#   VERBOSE=true                                            # Show all the executed commands, default is 'false'
#
# Exit codes:
#   0 - All files are formatted correctly
#   1 - Files are not formatted correctly, or the check mode is not recognised
#
# Notes:
#   1) Check modes select existing Markdown files known to Git, as described in
#      './scripts/quality/git-files.lib.sh'. Untracked files are never checked.
#   2) Enable markdownlint in your IDE. For Visual Studio Code, the
#      'davidanson.vscode-markdownlint' extension is listed in
#      './.vscode/extensions.json'.
#   3) The full list of rules is at
#      https://github.com/DavidAnson/markdownlint/blob/main/doc/Rules.md
#   4) The frontmatter check runs python3 on the host, never in Docker.
#      python3 is available wherever pre-commit runs.

# ==============================================================================

# Run markdown format checks in native or Docker mode.
function main() {

  cd "$(git rev-parse --show-toplevel)"

  # shellcheck disable=SC1091
  source ./scripts/quality/git-files.lib.sh
  local -a files=()
  quality-collect-git-files files "${check:-working-tree-changes}" '*.md' || return "$?"

  if [[ ${#files[@]} -gt 0 ]]; then
    if command -v markdownlint > /dev/null 2>&1 && ! is-arg-true "${FORCE_USE_DOCKER:-false}"; then
      run-markdownlint-natively "${files[@]}" || return "$?"
    else
      run-markdownlint-in-docker "${files[@]}" || return "$?"
    fi
    check-frontmatter-blank-line "${files[@]}" || return "$?"
  fi

  return 0
}

# Run markdownlint natively.
# Arguments:
#   $@=[files to check]
function run-markdownlint-natively() {

  markdownlint \
    "$@" \
    --config "$PWD/scripts/config/markdownlint.yaml" \
    --ignore-path "$PWD/scripts/config/.markdownlintignore" || return "$?"

  return 0
}

# Run markdownlint in a Docker container.
# Arguments:
#   $@=[files to check]
function run-markdownlint-in-docker() {

  # shellcheck disable=SC1091
  source ./scripts/docker/docker.lib.sh

  local image
  image=$(name=ghcr.io/igorshubovych/markdownlint-cli docker-get-image-version-and-pull) || return "$?"

  docker run --rm --platform linux/amd64 \
    --network none \
    --volume "$PWD":/workdir:ro \
    --workdir /workdir \
    "$image" \
      "$@" \
      --config /workdir/scripts/config/markdownlint.yaml \
      --ignore-path /workdir/scripts/config/.markdownlintignore || return "$?"

  return 0
}

# Check that a blank line follows the closing '---' of YAML frontmatter.
# markdownlint has no rule for this, because MD022 ignores frontmatter.
# Arguments:
#   $@=[files to check]
function check-frontmatter-blank-line() {

  python3 - "$@" <<'PY' || return "$?"
import sys
files = sys.argv[1:]
violations = []
encoding_warnings = []
for path in files:
    try:
        with open(path, encoding="utf-8") as fh:
            lines = fh.read().splitlines()
    except OSError:
        continue
    except UnicodeDecodeError as exc:
        # Surface non-UTF-8 files instead of silently skipping the check for them.
        encoding_warnings.append(f"{path}: skipped, not valid UTF-8 ({exc})")
        continue
    if not lines or lines[0].rstrip() != "---":
        continue
    end = None
    for i in range(1, len(lines)):
        if lines[i].rstrip() == "---":
            end = i
            break
    if end is None:
        continue
    if end + 1 < len(lines) and lines[end + 1].strip() != "":
        violations.append(f"{path}:{end + 2}: missing blank line after YAML frontmatter")
if encoding_warnings:
    sys.stderr.write("\n".join(encoding_warnings) + "\n")
if violations:
    sys.stderr.write("\n".join(violations) + "\n")
    sys.exit(1)
PY

  return 0
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
