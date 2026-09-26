#!/bin/bash
# shellcheck disable=SC1091,SC2034,SC2317,SC2329

set -euo pipefail

# Test suite for the GNU toolchain verification script. The version comparison
# is tested in process, by example and by property against 'sort -V'. The script
# itself runs with only fake tools and a few real ones on PATH, so the result
# never depends on what is installed on the host.
#
# Usage:
#   $ ./scripts/toolchain/tests/verify-gnu.test.sh
#
# Arguments (provided as environment variables):
#   VERBOSE=true  # Show all the executed commands, default is 'false'

# ==============================================================================

function main() {

  cd "$(git rev-parse --show-toplevel)"
  source ./scripts/tests/test.lib.sh

  test-run-suite \
    test-version-ge-examples \
    test-version-ge-properties \
    test-verify-gnu-passes-when-every-tool-is-gnu \
    test-verify-gnu-rejects-bsd-grep-that-claims-gnu-compatibility \
    test-verify-gnu-reports-missing-tool \
    test-verify-gnu-rejects-old-or-non-gnu-make \
    test-verify-gnu-accepts-podman-and-reports-no-runtime \
    test-verify-gnu-prints-platform-specific-hint

  return 0
}

# Create the one executable every fake tool links to, and run it once so macOS
# assesses it here rather than in each test.
function test-suite-setup() {

  FAKE_TOOL="$SUITE_TMP/fake-tool"
  cat > "$FAKE_TOOL" << 'EOF'
#!/bin/bash
# A link named NAME prints the lines of .NAME.fake beside it after the first, to
# stdout for a "1 " prefix and to stderr for "2 ", then exits with the status on the first line
{
  read -r status
  while IFS= read -r line; do
    if [[ "$line" == "2 "* ]]; then
      printf '%s\n' "${line#2 }" >&2
    else
      printf '%s\n' "${line#1 }"
    fi
  done
} < "${0%/*}/.${0##*/}.fake"
exit "$status"
EOF
  chmod +x "$FAKE_TOOL"
  printf '0\n' > "$SUITE_TMP/.fake-tool.fake"
  "$FAKE_TOOL"

  return 0
}

# ==============================================================================

function test-version-ge-examples() {

  # Arrange
  local example a b expected="" actual=""
  local examples=(
    "4.4.1 3.82 0" "3.82 3.82 0" "3.81 3.82 1" "3.82.90 3.82 0"
    "10.0 9.9 0" "3.9 3.82 1" "3.82.1-rc1 3.82 0" "4 3.82 0"
    "3.82 3.82.0 0" "3.82 3.82.1 1" "3.082 3.82 0"
  )
  source-verify-gnu
  # Act
  for example in "${examples[@]}"; do
    a="${example%% *}"
    b="${example#* }"
    b="${b% *}"
    ge-status "$a" "$b"
    expected="$expected$example"$'\n'
    actual="$actual$a $b $GE"$'\n'
  done
  # Assert
  assert-equal "$expected" "$actual" "version-ge status for each 'a b' example"

  return 0
}

function test-version-ge-properties() {

  # Arrange
  local seed=20260926 count=150 i a b suffix ab ba ab_suffix aa gt=0 lt=0 eq=0 where
  local -a lefts=() rights=() suffixes=()
  # Without its suffix strip, version-ge misreads each of these by value or syntax
  local suffix_set=(rc2 -2 -1ubuntu1 +2 b1)
  source-verify-gnu
  RANDOM=$seed
  for ((i = 0; i < count; i++)); do
    random-version-pair
    lefts+=("$PAIR_LEFT")
    rights+=("$PAIR_RIGHT")
    suffixes+=("${suffix_set[RANDOM % ${#suffix_set[@]}]}")
    printf '%s %s\n' "$PAIR_LEFT" "$PAIR_RIGHT" >> "$TEST_TMP/pairs"
  done
  set-sort-v-oracle "$TEST_TMP/pairs"
  # Act and Assert
  for ((i = 0; i < count; i++)); do
    a="${lefts[i]}"
    b="${rights[i]}"
    suffix="${suffixes[i]}"
    where="seed $seed, iteration $i, a=$a, b=$b, suffix=$suffix"
    ge-status "$a" "$a"
    aa=$GE
    ge-status "$a" "$b"
    ab=$GE
    ge-status "$b" "$a"
    ba=$GE
    ge-status "$a$suffix" "$b"
    ab_suffix=$GE
    assert-equal 0 "$aa" "reflexive: version-ge a a ($where)"
    assert-equal 0 "$((ab * ba))" "total: version-ge a b or version-ge b a ($where)"
    assert-equal "${ORACLE[i]}" "$ab $ba" "oracle: statuses of version-ge a b and b a match sort -V ($where)"
    assert-equal "$ab" "$ab_suffix" "suffix invariance: version-ge a<suffix> b ($where)"
    case "$ab$ba" in
      00) eq=$((eq + 1)) ;;
      01) gt=$((gt + 1)) ;;
      10) lt=$((lt + 1)) ;;
    esac
  done
  # A generator that rarely yields one of the outcomes would leave that case untested
  assert-equal 1 "$((eq >= 20 && gt >= 20 && lt >= 20))" \
    "at least 20 pairs of each outcome (equal $eq, greater $gt, lesser $lt)"

  return 0
}

function test-verify-gnu-passes-when-every-tool-is-gnu() {

  # Arrange
  local f="$TEST_TMP/fakes" expected
  expected="$(printf '%s\n' \
    "OK       awk: GNU Awk 5.3.0 ($f/awk)" \
    "OK       date: date (GNU coreutils) 9.5 ($f/date)" \
    "OK       diff: diff (GNU diffutils) 3.10 ($f/diff)" \
    "OK       find: find (GNU findutils) 4.10.0 ($f/find)" \
    "OK       grep: grep (GNU grep) 3.11 ($f/grep)" \
    "OK       sed: sed (GNU sed) 4.9 ($f/sed)" \
    "OK       make: GNU Make 4.4.1 ($f/make)" \
    "OK       docker: $f/docker" \
    "All GNU tools verified.")"
  create-minbin
  create-gnu-fakes
  # Act
  run-verify-gnu
  # Assert
  assert-equal 0 "$TEST_STATUS" "exit status"
  assert-equal "$expected" "$TEST_STDOUT" "stdout"
  assert-equal "" "$TEST_STDERR" "stderr"

  return 0
}

function test-verify-gnu-rejects-bsd-grep-that-claims-gnu-compatibility() {

  # Arrange
  create-minbin
  create-gnu-fakes
  create-fake-tool grep "grep (BSD grep, GNU compatible) 2.6.0-FreeBSD"
  # Act
  run-verify-gnu
  # Assert
  assert-equal 1 "$TEST_STATUS" "exit status"
  assert-contains "$TEST_STDOUT" "NOT GNU  grep: grep (BSD grep, GNU compatible) 2.6.0-FreeBSD ($TEST_TMP/fakes/grep)"
  assert-contains "$TEST_STDOUT" "1 tool(s) are not resolving"

  return 0
}

function test-verify-gnu-reports-missing-tool() {

  # Arrange
  create-minbin
  create-gnu-fakes sed
  # Act
  run-verify-gnu
  # Assert
  assert-equal 1 "$TEST_STATUS" "exit status"
  assert-contains "$TEST_STDOUT" "MISSING  sed: not found on PATH"
  assert-contains "$TEST_STDOUT" "1 tool(s) are not resolving"

  return 0
}

function test-verify-gnu-rejects-old-or-non-gnu-make() {

  # Arrange
  local old_status old_stdout
  create-minbin
  create-gnu-fakes
  create-fake-tool make "GNU Make 3.81"
  # Act
  run-verify-gnu
  old_status=$TEST_STATUS
  old_stdout="$TEST_STDOUT"
  # Exits non-zero like a BSD make rejecting --version on stderr
  create-fake-tool make "" 2 $'make: illegal option -- -\nusage: make [-BeikNnqrSstWwX] [-C directory]'
  run-verify-gnu
  # Assert
  assert-equal "1 1" "$old_status $TEST_STATUS" "exit status with the old make, then the non-GNU make"
  assert-contains "$old_stdout" "TOO OLD  make: GNU Make 3.81 ($TEST_TMP/fakes/make), need 3.82 or later"
  assert-contains "$TEST_STDOUT" "NOT GNU  make: make: illegal option -- - ($TEST_TMP/fakes/make)"

  return 0
}

function test-verify-gnu-accepts-podman-and-reports-no-runtime() {

  # Arrange
  local podman_status podman_stdout
  create-minbin
  create-gnu-fakes docker
  create-fake-tool podman "podman version 5.2.0"
  # Act
  run-verify-gnu
  podman_status=$TEST_STATUS
  podman_stdout="$TEST_STDOUT"
  rm "$TEST_TMP/fakes/podman"
  run-verify-gnu
  # Assert
  assert-equal "0 1" "$podman_status $TEST_STATUS" "exit status with podman, then with no runtime"
  assert-contains "$podman_stdout" "OK       podman: $TEST_TMP/fakes/podman"
  assert-contains "$TEST_STDOUT" "MISSING  docker/podman: neither found on PATH"

  return 0
}

function test-verify-gnu-prints-platform-specific-hint() {

  # Arrange
  local darwin_status darwin_stdout
  create-minbin
  create-gnu-fakes sed
  create-fake-tool uname Darwin
  # Act
  run-verify-gnu
  darwin_status=$TEST_STATUS
  darwin_stdout="$TEST_STDOUT"
  create-fake-tool uname Linux
  run-verify-gnu
  # Assert
  assert-equal "1 1" "$darwin_status $TEST_STATUS" "exit status on macOS, then on Linux"
  assert-contains "$darwin_stdout" "Run: make toolchain-install-gnu-macos"
  assert-not-contains "$darwin_stdout" "apt-get"
  assert-contains "$TEST_STDOUT" "sudo apt-get install gawk"
  assert-not-contains "$TEST_STDOUT" "toolchain-install-gnu-macos"

  return 0
}

# ==============================================================================

# Create a fake tool in "$TEST_TMP/fakes" that prints the given text whatever its
# arguments. Not test-stub, since the stub directory is first on the harness's
# own PATH and a fake grep or sed there would break the assertions.
# Arguments:
#   $1=[command name]
#   $2=[lines it prints to stdout, none if empty]
#   $3=[exit status, default is 0]
#   $4=[lines it then prints to stderr, default is none]
function create-fake-tool() {

  local dir="$TEST_TMP/fakes" line
  [[ -d "$dir" ]] || mkdir "$dir"
  {
    printf '%s\n' "${3:-0}"
    if [[ -n "$2" ]]; then
      while IFS= read -r line; do printf '1 %s\n' "$line"; done <<< "$2"
    fi
    if [[ -n "${4:-}" ]]; then
      while IFS= read -r line; do printf '2 %s\n' "$line"; done <<< "$4"
    fi
  } > "$dir/.$1.fake"
  ln -sf "$FAKE_TOOL" "$dir/$1"

  return 0
}

# Create a fake GNU awk, date, diff, find, grep, sed and make, and a fake docker.
# The grep and make fakes print a second line, as the real tools do.
# Arguments:
#   $@=[names of the fakes to leave out]
function create-gnu-fakes() {

  local fake name
  local fakes=(
    "awk:GNU Awk 5.3.0" "date:date (GNU coreutils) 9.5" "diff:diff (GNU diffutils) 3.10"
    "find:find (GNU findutils) 4.10.0" $'grep:grep (GNU grep) 3.11\nCopyright (C) 2023 Free Software Foundation, Inc.'
    "sed:sed (GNU sed) 4.9" $'make:GNU Make 4.4.1\nBuilt for aarch64-apple-darwin24.0.0'
    "docker:Docker version 27.3.1, build ce12230"
  )
  for fake in "${fakes[@]}"; do
    name="${fake%%:*}"
    [[ " $* " != *" $name "* ]] || continue
    create-fake-tool "$name" "${fake#*:}"
  done

  return 0
}

# Create "$TEST_TMP/minbin" with links to the real bash, head and uname, the only
# real tools the script under test gets.
function create-minbin() {

  mkdir "$TEST_TMP/minbin"
  ln -s "$(type -P bash)" "$(type -P head)" "$(type -P uname)" "$TEST_TMP/minbin/"

  return 0
}

# Run the script under test with only the fakes and the minimal real tools on
# PATH and nothing else from the caller's environment.
function run-verify-gnu() {

  test-capture env -i PATH="$TEST_TMP/fakes:$TEST_TMP/minbin" "$TEST_REPO_ROOT/scripts/toolchain/verify-gnu.sh"

  return 0
}

# Source the script under test to reach its functions, with only rm on PATH, for
# the harness clean-up, so that main fails the test if the source guard ever stops working.
function source-verify-gnu() {

  local saved_path="$PATH" bin="$TEST_TMP/rm-only"
  mkdir "$bin"
  ln -s "$(type -P rm)" "$bin/rm"
  PATH="$bin"
  source "$TEST_REPO_ROOT/scripts/toolchain/verify-gnu.sh"
  PATH="$saved_path"

  return 0
}

# Set GE to the exit status of version-ge for the given versions. check-make
# also calls version-ge as a condition, so errexit is off inside it there too.
# Arguments:
#   $1=[version to check]
#   $2=[minimum required version]
function ge-status() {

  GE=0
  version-ge "$1" "$2" || GE=1

  return 0
}

# Set ORACLE to one "S T" line per "a b" line of the given file, where S and T
# are the statuses 'sort -V' implies for version-ge a b and version-ge b a.
# One 'sort -V' over every version orders each pair as sorting the pair alone would.
# Arguments:
#   $1=[file of "a b" version pairs]
function set-sort-v-oracle() {

  local pairs="$1" line
  awk '{ print $1; print $2 }' "$pairs" | LC_ALL=C sort -V > "$TEST_TMP/sorted"
  awk '
    FILENAME == ARGV[1] { if (!($0 in rank)) rank[$0] = FNR; next }
    { print (rank[$1] >= rank[$2] ? 0 : 1) " " (rank[$2] >= rank[$1] ? 0 : 1) }
  ' "$TEST_TMP/sorted" "$pairs" > "$TEST_TMP/oracle"
  ORACLE=()
  while IFS= read -r line; do
    ORACLE+=("$line")
  done < "$TEST_TMP/oracle"

  return 0
}

# Set REPLY to a random dotted version of the given number of components, each
# from 0 to 120 with the last at least 1, so it never ends in a zero component.
# Half the components are 3 or less, to reach the 0 and 1 edge cases often.
# Arguments:
#   $1=[number of components]
function random-version() {

  local n="$1" i max
  REPLY=""
  for ((i = 1; i <= n; i++)); do
    max=121
    [[ $((RANDOM % 2)) -eq 0 ]] || max=4
    if [[ $i -lt $n ]]; then
      REPLY="$REPLY$((RANDOM % max))."
    else
      REPLY="$REPLY$((RANDOM % (max - 1) + 1))"
    fi
  done

  return 0
}

# Set PAIR_LEFT and PAIR_RIGHT to random versions of 1 to 4 components. A third
# of the pairs are equal and a third share a leading part, since independent
# versions nearly always differ in their first component.
function random-version-pair() {

  local -a parts
  local keep prefix="" i

  random-version $((RANDOM % 4 + 1))
  PAIR_LEFT="$REPLY"
  case $((RANDOM % 3)) in
    0)
      PAIR_RIGHT="$PAIR_LEFT"
      ;;
    1)
      random-version $((RANDOM % 4 + 1))
      PAIR_RIGHT="$REPLY"
      ;;
    2)
      IFS='.' read -r -a parts <<< "$PAIR_LEFT"
      keep=$((RANDOM % (${#parts[@]} + 1)))
      [[ $keep -lt 4 ]] || keep=3
      for ((i = 0; i < keep; i++)); do
        prefix="$prefix${parts[i]}."
      done
      random-version $((RANDOM % (4 - keep) + 1))
      PAIR_RIGHT="$prefix$REPLY"
      ;;
  esac

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
