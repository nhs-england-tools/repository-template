#!/bin/bash

set -euo pipefail

# Install the GNU userland tools this repository's own scripts rely on, via
# Homebrew. macOS ships BSD equivalents that are behaviourally incompatible
# with the GNU-only flags used in scripts/docker/docker.lib.sh (bare `sed -i`
# in-place edits, `date --date=`). On Linux this is a no-op, because the GNU
# tools come from the system package manager (Debian and Ubuntu need the gawk
# package, since they ship mawk as awk). See scripts/toolchain/verify-gnu.sh
# to confirm the effective tools on PATH are the GNU ones.
#
# GNU binutils is deliberately not installed: its unprefixed 'ar' and 'ranlib'
# write archives that Apple's linker rejects when they shadow the Apple tools.
#
# Usage:
#   $ ./install-gnu-macos.sh
#
# Options:
#   VERBOSE=true  # Show all the executed commands, default is 'false'
#
# Exit codes:
#   0 - The tools are installed, or there is nothing to do on this OS
#   1 - Homebrew is not installed, or a Homebrew command failed

FORMULAE=(coreutils diffutils findutils gawk gnu-sed grep)

# ==============================================================================

function main() {

  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Not macOS, nothing to do. On Linux, install any missing GNU tools with the system package manager, then run: make toolchain-verify-gnu"
    exit 0
  fi

  command -v brew > /dev/null 2>&1 || { echo "Homebrew is not installed, see https://brew.sh/" >&2; exit 1; }

  brew install "${FORMULAE[@]}"

  recommend-path

  return 0
}

# Print the PATH directory a formula's GNU binaries need added to PATH, or
# nothing if the formula doesn't need one.
# Arguments:
#   $1=[formula name, e.g. 'gnu-sed']
function formula-gnu-dir() {

  local formula="$1" prefix
  prefix="$(brew --prefix "${formula}")"

  # Not every formula renames its binaries (e.g. diffutils installs
  # cmp/diff/diff3/sdiff unprefixed with no gnubin dir at all, already
  # reachable via the normal linked prefix), so only formulae that actually
  # have a gnubin dir need a PATH entry.
  if [[ -d "${prefix}/libexec/gnubin" ]]; then
    echo "${prefix}/libexec/gnubin"
  fi

  return 0
}

# Print the PATH export line needed for the installed formulae's GNU binaries
# to shadow the BSD ones, and optionally append it to the user's shell rc file.
function recommend-path() {

  local formula dir missing=()

  for formula in "${FORMULAE[@]}"; do
    dir="$(formula-gnu-dir "${formula}")"
    [[ -n "${dir}" ]] || continue
    case ":${PATH}:" in
      *":${dir}:"*) ;;
      *) missing+=("${dir}") ;;
    esac
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    echo "PATH already includes every installed GNU gnubin directory."
    return 0
  fi

  local line
  line="$(path-line "${missing[@]}")"

  {
    echo
    echo "Add this to your shell profile so 'sed', 'grep', 'date', 'awk', 'find' and others resolve to the GNU versions:"
    echo
    echo "  ${line}"
    echo
  } >&2

  offer-append "${line}"

  return 0
}

# Print the line that prepends the given directories to PATH, in the syntax of
# the user's login shell (fish differs from POSIX shells).
# Arguments:
#   $@=[directories to prepend, in order]
function path-line() {

  local dir quoted=()

  case "${SHELL:-}" in
    */fish)
      for dir in "$@"; do
        quoted+=("\"${dir}\"")
      done
      echo "fish_add_path --path --prepend ${quoted[*]}"
      ;;
    *)
      local IFS=:
      echo "export PATH=\"$*:\${PATH}\""
      ;;
  esac

  return 0
}

# Offer to append the recommended line to the user's shell rc file. Only
# prompts when connected to an interactive terminal. Otherwise it just prints
# the instruction and returns, so this is safe to run from CI or a script.
# Arguments:
#   $1=[line to append]
function offer-append() {

  local line="$1" rc_file="" reply=""

  case "${SHELL:-}" in
    */zsh) rc_file="${ZDOTDIR:-${HOME}}/.zshrc" ;;
    */bash) rc_file="$(bash-login-file)" ;;
    */fish) rc_file="${XDG_CONFIG_HOME:-${HOME}/.config}/fish/config.fish" ;;
  esac

  if [[ -z "${rc_file}" ]] || [[ ! -t 0 ]]; then
    echo "Add the line above to your shell profile manually." >&2
    return 0
  fi

  # 'read' fails on end of input (Ctrl-D), which 'set -e' would turn into an exit
  read -r -p "Append this line to ${rc_file} now? [y/N] " reply || { reply=""; echo >&2; }
  if [[ "${reply}" =~ ^[Yy]$ ]]; then
    mkdir -p "$(dirname "${rc_file}")"
    printf '\n# Added by scripts/toolchain/install-gnu-macos.sh\n%s\n' "${line}" >> "${rc_file}"
    echo "Appended. Restart your shell or run: source ${rc_file}" >&2
  else
    echo "Skipped. Add the line above manually when you're ready." >&2
  fi

  return 0
}

# Print the file a bash login shell reads, which is the first of these that
# exists. macOS terminals start bash as a login shell, so ~/.bashrc is not read.
# Creating ~/.bash_profile when ~/.profile exists would stop bash reading it.
function bash-login-file() {

  local file

  for file in "${HOME}/.bash_profile" "${HOME}/.bash_login" "${HOME}/.profile"; do
    if [[ -f "${file}" ]]; then
      echo "${file}"
      return 0
    fi
  done
  echo "${HOME}/.bash_profile"

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
