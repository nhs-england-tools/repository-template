#!/usr/bin/env bash

set -euo pipefail

# Pre-commit git hook to check the Markdown file formatting rules compliance
# over changed files. This is a markdownlint command wrapper. It will run
# markdownlint natively if it is installed, otherwise it will run it in a Docker
# container.
#
# Usage:
#   $ [options] ./check-markdown-format.sh
#
# Options:
#   check={all,staged-changes,working-tree-changes,branch}  # Check mode, default is 'working-tree-changes'
#   BRANCH_NAME=other-branch-than-main                      # Branch to compare with, default is `origin/main`
#   FORCE_USE_DOCKER=true                                   # If set to true the command is run in a Docker container, default is 'false'
#   VERBOSE=true                                            # Show all the executed commands, default is `false`
#
# Exit codes:
#   0 - All files are formatted correctly
#   1 - Files are not formatted correctly
#
# Notes:
#   1) Please make sure to enable Markdown linting in your IDE. For the Visual
#   Studio Code editor it is `davidanson.vscode-markdownlint` that is already
#   specified in the `./.vscode/extensions.json` file.
#   2) To see the full list of the rules, please visit
#   https://github.com/DavidAnson/markdownlint/blob/main/doc/Rules.md
#   3) The frontmatter blank-line check requires `python3` on the host; it is not
#   run through Docker. `python3` is present wherever `pre-commit` runs.

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
    --volume "$PWD":/workdir \
    --workdir /workdir \
    "$image" \
      "$@" \
      --config /workdir/scripts/config/markdownlint.yaml \
      --ignore-path /workdir/scripts/config/.markdownlintignore || return "$?"

  return 0
}

# Enforce a blank line between the YAML frontmatter closing `---` and the
# following content. `markdownlint` does not provide a built-in rule for this
# (MD022 ignores frontmatter delimiters), so we enforce it here.
# Arguments:
#   $@=[files to check]
function check-frontmatter-blank-line() {

  python3 - "$@" <<'PY'
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
}

# ==============================================================================

# Check whether the supplied argument represents a true boolean value.
# Arguments:
#   $1=[value to evaluate]
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
