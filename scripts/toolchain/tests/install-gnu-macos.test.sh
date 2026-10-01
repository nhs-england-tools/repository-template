#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2317,SC2329

set -euo pipefail

# Test suite for the macOS GNU toolchain installer. Each test runs the script
# with 'uname' and 'brew' stubbed and with 'env -i', so only PATH and the shell
# variables the test passes reach it. The interactive y/N prompt is not tested,
# because it needs stdin to be a pseudo terminal.
#
# Usage:
#   $ ./scripts/toolchain/tests/install-gnu-macos.test.sh
#
# Arguments (provided as environment variables):
#   VERBOSE=true  # Show all the executed commands, default is 'false'

# ==============================================================================

readonly EXIT_STATUS_LABEL='exit status'

function main() {

  cd "$(git rev-parse --show-toplevel)"
  source ./scripts/tests/test.lib.sh

  MARKER="# Added by scripts/toolchain/install-gnu-macos.sh"

  test-run-suite \
    test-install-gnu-macos-is-a-no-op-off-macos \
    test-install-gnu-macos-requires-homebrew \
    test-install-gnu-macos-installs-formulae-and-recommends-path \
    test-install-gnu-macos-prints-fish-syntax \
    test-install-gnu-macos-keeps-leading-bash-in-posix-guidance \
    test-install-gnu-macos-keeps-leading-bash-in-fish-guidance \
    test-install-gnu-macos-reports-path-already-complete \
    test-install-gnu-macos-skips-when-rc-file-has-the-block \
    test-install-gnu-macos-uses-the-first-bash-login-file \
    test-direct-script-selects-bash-from-path \
    test-make-recipe-selects-bash-from-path

  return 0
}

# A wrapper ahead of the host Bash on PATH records interpreter selection and
# delegates to that Bash. Its POSIX sh shebang avoids calling itself again.
function create-bash-selection-wrapper() {

  local real_bash
  real_bash="$(type -P bash)"
  mkdir -p "$TEST_TMP/selected-bin"
  cat > "$TEST_TMP/selected-bin/bash" << EOF
#!/bin/sh
printf 'selected\n' >> '$TEST_TMP/bash-selection.log'
printf '%s\n' "\${1-}" >> '$TEST_TMP/bash-script-args.log'
export SELECTED_BASH_WRAPPER=1
exec '$real_bash' "\$@"
EOF
  chmod +x "$TEST_TMP/selected-bin/bash"

  return 0
}

function test-direct-script-selects-bash-from-path() {

  create-bash-selection-wrapper
  test-stub uname 'echo Linux'
  test-capture env PATH="$TEST_TMP/selected-bin:$PATH" \
    "$TEST_REPO_ROOT/scripts/toolchain/install-gnu-macos.sh"
  assert-equal 0 "$TEST_STATUS" "direct script exit status"
  assert-file-has-line "$TEST_TMP/bash-script-args.log" \
    "$TEST_REPO_ROOT/scripts/toolchain/install-gnu-macos.sh"

  return 0
}

function test-make-recipe-selects-bash-from-path() {

  create-bash-selection-wrapper
  # Make must receive literal $$ so it passes $ to the recipe shell.
  # shellcheck disable=SC2016
  printf 'shell-selection-probe:\n\t@test "$$SELECTED_BASH_WRAPPER" = 1\n' > "$TEST_TMP/probe.mk"
  test-capture env PATH="$TEST_TMP/selected-bin:$PATH" \
    make -f "$TEST_REPO_ROOT/Makefile" -f "$TEST_TMP/probe.mk" shell-selection-probe
  assert-equal 0 "$TEST_STATUS" "Make recipe exit status"
  assert-contains "$(cat "$TEST_TMP/bash-selection.log")" selected \
    "Make recipe interpreter"

  return 0
}

# ==============================================================================

function test-install-gnu-macos-is-a-no-op-off-macos() {

  # Arrange
  arrange-os-and-brew Linux
  # Act
  run-install-gnu-macos SHELL=/bin/zsh HOME="$TEST_TMP/home"
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-matches "$TEST_STDOUT" '^Not macOS, nothing to do\.' "stdout"
  assert-stub-not-called brew

  return 0
}

function test-install-gnu-macos-requires-homebrew() {

  # Arrange
  test-isolate-path
  test-stub uname 'echo Darwin'
  # Act
  run-install-gnu-macos SHELL=/bin/zsh HOME="$TEST_TMP/home"
  # Assert
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "Homebrew is not installed"

  return 0
}

function test-install-gnu-macos-installs-formulae-and-recommends-path() {

  # Arrange
  local b="$TEST_TMP/brew" expected
  expected="export PATH=\"$b/bash/bin:$b/coreutils/libexec/gnubin:$b/findutils/libexec/gnubin:$b/gawk/libexec/gnubin:$b/gnu-sed/libexec/gnubin:$b/grep/libexec/gnubin:\${PATH}\""
  arrange-os-and-brew Darwin
  PATH="$PATH:$b/bash/bin"
  # Act
  run-install-gnu-macos SHELL=/bin/zsh HOME="$TEST_TMP/home"
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-stub-called brew "install bash coreutils diffutils findutils gawk gnu-sed grep"
  assert-contains "$TEST_STDERR" "  $expected"
  assert-contains "$TEST_STDERR" "Add the line above to your shell profile manually."
  assert-file-not-exists "$TEST_TMP/home/.zshrc"

  return 0
}

function test-install-gnu-macos-prints-fish-syntax() {

  # Arrange
  local b="$TEST_TMP/brew" expected
  expected="fish_add_path --path --prepend --move \"$b/bash/bin\" \"$b/coreutils/libexec/gnubin\" \"$b/findutils/libexec/gnubin\" \"$b/gawk/libexec/gnubin\" \"$b/gnu-sed/libexec/gnubin\" \"$b/grep/libexec/gnubin\""
  arrange-os-and-brew Darwin
  PATH="$PATH:$b/bash/bin"
  # Act
  run-install-gnu-macos SHELL=/usr/bin/fish HOME="$TEST_TMP/home"
  # Assert
  assert-equal 0 "$TEST_STATUS" "exit status"
  assert-contains "$TEST_STDERR" "  $expected"

  return 0
}

function test-install-gnu-macos-keeps-leading-bash-in-posix-guidance() {

  # Arrange
  local b="$TEST_TMP/brew" expected
  expected="export PATH=\"$b/bash/bin:$b/coreutils/libexec/gnubin:$b/findutils/libexec/gnubin:$b/gawk/libexec/gnubin:$b/gnu-sed/libexec/gnubin:$b/grep/libexec/gnubin:\${PATH}\""
  arrange-os-and-brew Darwin
  PATH="$b/bash/bin:$PATH"
  # Act
  run-install-gnu-macos SHELL=/bin/zsh HOME="$TEST_TMP/home"
  # Assert
  assert-equal 0 "$TEST_STATUS" "exit status"
  assert-contains "$TEST_STDERR" "  $expected"

  return 0
}

function test-install-gnu-macos-keeps-leading-bash-in-fish-guidance() {

  # Arrange
  local b="$TEST_TMP/brew" expected
  expected="fish_add_path --path --prepend --move \"$b/bash/bin\" \"$b/coreutils/libexec/gnubin\" \"$b/findutils/libexec/gnubin\" \"$b/gawk/libexec/gnubin\" \"$b/gnu-sed/libexec/gnubin\" \"$b/grep/libexec/gnubin\""
  arrange-os-and-brew Darwin
  PATH="$b/bash/bin:$PATH"
  # Act
  run-install-gnu-macos SHELL=/usr/bin/fish HOME="$TEST_TMP/home"
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "  $expected"

  return 0
}

function test-install-gnu-macos-reports-path-already-complete() {

  # Arrange
  local b="$TEST_TMP/brew" formula
  arrange-os-and-brew Darwin
  PATH="$b/bash/bin:$PATH"
  for formula in coreutils findutils gawk gnu-sed grep; do
    PATH="$PATH:$b/$formula/libexec/gnubin"
  done
  # Act
  run-install-gnu-macos SHELL=/bin/zsh HOME="$TEST_TMP/home"
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-equal "PATH already includes every installed GNU gnubin directory." "$TEST_STDOUT" "stdout"
  assert-equal "" "$TEST_STDERR" "stderr"

  return 0
}

function test-install-gnu-macos-skips-when-rc-file-has-the-block() {

  # Arrange
  local zdot="$TEST_TMP/zdot"
  arrange-os-and-brew Darwin
  mkdir "$zdot"
  printf 'alias ll="ls -l"\n\n%s\nexport EDITOR=vim\n' "$MARKER" > "$zdot/.zshrc"
  cp "$zdot/.zshrc" "$TEST_TMP/zshrc.before"
  # Act
  run-install-gnu-macos SHELL=/bin/zsh HOME="$TEST_TMP/home" ZDOTDIR="$zdot"
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL"
  assert-contains "$TEST_STDERR" "$zdot/.zshrc already has a block added by this script"
  assert-contains "$TEST_STDERR" "Update the existing block manually with the line above."
  assert-not-contains "$TEST_STDERR" "Restart your shell or run: source"
  assert-not-contains "$TEST_STDERR" "Add the line above to your shell profile manually."
  assert-files-identical "$TEST_TMP/zshrc.before" "$zdot/.zshrc"

  return 0
}

function test-install-gnu-macos-uses-the-first-bash-login-file() {

  # Arrange
  local home="$TEST_TMP/home" profile_status profile_stderr
  arrange-os-and-brew Darwin
  mkdir "$home"
  printf '%s\n' "$MARKER" > "$home/.profile"
  cp "$home/.profile" "$TEST_TMP/profile.before"
  # Act
  run-install-gnu-macos SHELL=/bin/bash HOME="$home"
  profile_status=$TEST_STATUS
  profile_stderr="$TEST_STDERR"
  printf 'alias ll="ls -l"\n%s\n' "$MARKER" > "$home/.bash_profile"
  cp "$home/.bash_profile" "$TEST_TMP/bash_profile.before"
  run-install-gnu-macos SHELL=/bin/bash HOME="$home"
  # Assert
  assert-equal "0 0" "$profile_status $TEST_STATUS" "exit status with only .profile, then with .bash_profile too"
  assert-contains "$profile_stderr" "$home/.profile already has a block added by this script" "only .profile exists"
  assert-contains "$TEST_STDERR" "$home/.bash_profile already has a block added by this script" ".bash_profile and .profile exist"
  assert-files-identical "$TEST_TMP/profile.before" "$home/.profile"
  assert-files-identical "$TEST_TMP/bash_profile.before" "$home/.bash_profile"

  return 0
}

# ==============================================================================

# Isolate PATH, stub uname to print the given OS, and stub brew so that
# 'brew --prefix <formula>' prints "$TEST_TMP/brew/<formula>". Every formula
# prefix has a libexec/gnubin directory except diffutils, as in Homebrew.
# Arguments:
#   $1=[OS name uname prints, e.g. 'Darwin']
function arrange-os-and-brew() {

  local os="$1" b="$TEST_TMP/brew"
  test-isolate-path
  test-stub uname "echo $os"
  # The body expands TEST_TMP now, because 'env -i' keeps it from the stub
  test-stub brew "[[ \"\${1:-}\" != --prefix ]] || printf '%s\n' \"$b/\${2:-}\""
  mkdir -p "$b/bash/bin" "$b/coreutils/libexec/gnubin" "$b/diffutils" "$b/findutils/libexec/gnubin" \
    "$b/gawk/libexec/gnubin" "$b/gnu-sed/libexec/gnubin" "$b/grep/libexec/gnubin"

  return 0
}

# Run the script under test with the test's PATH and only the given variables.
# Arguments:
#   $@=[NAME=VALUE environment variables, e.g. 'SHELL=/bin/zsh']
function run-install-gnu-macos() {

  test-capture env -i PATH="$PATH" "$@" "$TEST_REPO_ROOT/scripts/toolchain/install-gnu-macos.sh"

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
