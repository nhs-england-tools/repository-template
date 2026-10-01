#!/usr/bin/env bash

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
# Homebrew's 'bash' formula is also installed, because macOS ships bash 3.2
# (its last GPLv2 release) as /bin/bash and never updates it. This does not
# touch /bin/bash or the default login shell; it only adds a newer bash to
# PATH ahead of the GNU utility directories, for scripts that need Bash 5.2+.
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

FORMULAE=(bash coreutils diffutils findutils gawk gnu-sed grep)

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

  # Homebrew's bash formula has no gnubin dir, it installs bash straight into
  # the formula's own bin dir, which needs to lead PATH ahead of every GNU
  # utility directory so it shadows /bin/bash for interactive/login shells.
  if [[ "${formula}" == "bash" ]]; then
    if [[ -d "${prefix}/bin" ]]; then
      echo "${prefix}/bin"
    fi
    return 0
  fi

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

  local formula dir bash_dir="" missing=()

  for formula in "${FORMULAE[@]}"; do
    dir="$(formula-gnu-dir "${formula}")"
    [[ -n "${dir}" ]] || continue
    if [[ "${formula}" == "bash" ]]; then
      bash_dir="${dir}"
      # Bash must lead PATH: merely appearing later can leave /bin/bash first.
      case "${PATH}" in
        "${dir}"|"${dir}":*) ;;
        *) missing+=("${dir}") ;;
      esac
      continue
    fi
    case ":${PATH}:" in
      *":${dir}:"*) ;;
      *) missing+=("${dir}") ;;
    esac
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    echo "PATH already includes every installed GNU gnubin directory."
    return 0
  fi

  # Prepending missing GNU directories would push even a leading Bash behind
  # them, so include Bash first in every generated PATH line.
  if [[ -n "${bash_dir}" && "${missing[0]}" != "${bash_dir}" ]]; then
    missing=("${bash_dir}" "${missing[@]}")
  fi

  local line
  line="$(path-line "${missing[@]}")"

  {
    echo
    echo "Add this to your shell profile so 'bash' resolves to the newer Homebrew version, and 'sed', 'grep', 'date', 'awk', 'find' and others resolve to the GNU versions:"
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
      echo "fish_add_path --path --prepend --move ${quoted[*]}"
      ;;
    *)
      local IFS=:
      echo "export PATH=\"$*:\${PATH}\""
      ;;
  esac

  return 0
}

# Offer to append the recommended line to the user's shell rc file. When the rc
# file already has the block, it prints the skip message and returns. Otherwise
# it only prompts when connected to an interactive terminal, and just prints
# the instruction when not, so this is safe to run from CI or a script.
# Arguments:
#   $1=[line to append]
function offer-append() {

  local line="$1" rc_file="" reply=""

  case "${SHELL:-}" in
    */zsh) rc_file="${ZDOTDIR:-${HOME}}/.zshrc" ;;
    */bash) rc_file="$(bash-login-file)" ;;
    */fish) rc_file="${XDG_CONFIG_HOME:-${HOME}/.config}/fish/config.fish" ;;
    *) rc_file="" ;; # Unknown shells use the manual setup instructions below
  esac

  if [[ -n "${rc_file}" ]] && [[ -f "${rc_file}" ]] && grep -Fq '# Added by scripts/toolchain/install-gnu-macos.sh' "${rc_file}"; then
    echo "${rc_file} already has a block added by this script, skipping. Update the existing block manually with the line above." >&2
    return 0
  fi

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
