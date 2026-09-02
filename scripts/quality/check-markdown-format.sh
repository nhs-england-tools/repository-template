#!/bin/bash

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

  local check=${check:-working-tree-changes}
  local files
  case $check in
    "all")
      files="$(git ls-files "*.md" | while IFS= read -r f; do if [[ -f "$f" ]]; then printf '%s\n' "$f"; fi; done)"
      ;;
    "staged-changes")
      files="$(git diff --diff-filter=ACMRT --name-only --cached "*.md")"
      ;;
    "working-tree-changes")
      files="$(git diff --diff-filter=ACMRT --name-only "*.md")"
      ;;
    "branch")
      files="$( (git diff --diff-filter=ACMRT --name-only "${BRANCH_NAME:-origin/main}" "*.md"; git diff --name-only "*.md") | sort | uniq )"
      ;;
    *)
      echo "Unrecognised check mode: $check" >&2 && exit 1
      ;;
  esac

  if [ -n "$files" ]; then
    if command -v markdownlint > /dev/null 2>&1 && ! is-arg-true "${FORCE_USE_DOCKER:-false}"; then
      files="$files" run-markdownlint-natively
    else
      files="$files" run-markdownlint-in-docker
    fi
    files="$files" check-frontmatter-blank-line
  fi

  return 0
}

# Run markdownlint natively.
# Arguments (provided as environment variables):
#   files=[files to check]
function run-markdownlint-natively() {

  # shellcheck disable=SC2086
  markdownlint \
    $files \
    --config "$PWD/scripts/config/markdownlint.yaml" \
    --ignore-path "$PWD/scripts/config/.markdownlintignore"

  return 0
}

# Run markdownlint in a Docker container.
# Arguments (provided as environment variables):
#   files=[files to check]
function run-markdownlint-in-docker() {

  # shellcheck disable=SC1091
  source ./scripts/docker/docker.lib.sh

  # shellcheck disable=SC2155
  local image=$(name=ghcr.io/igorshubovych/markdownlint-cli docker-get-image-version-and-pull)
  # shellcheck disable=SC2086
  docker run --rm --platform linux/amd64 \
    --volume "$PWD":/workdir \
    --workdir /workdir \
    "$image" \
      $files \
      --config /workdir/scripts/config/markdownlint.yaml \
      --ignore-path /workdir/scripts/config/.markdownlintignore

  return 0
}

# Enforce a blank line between the YAML frontmatter closing `---` and the
# following content. `markdownlint` does not provide a built-in rule for this
# (MD022 ignores frontmatter delimiters), so we enforce it here.
# Arguments (provided as environment variables):
#   files=[files to check]
function check-frontmatter-blank-line() {

  # No explicit `return 0` here: the python3 exit status is the result of the
  # check, so a violation (exit 1) must propagate to fail the check under set -e.
  python3 - <<'PY'
import os, sys
files = os.environ.get("files", "").split()
violations = []
for path in files:
    try:
        with open(path, encoding="utf-8") as fh:
            lines = fh.read().splitlines()
    except (OSError, UnicodeDecodeError):
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
