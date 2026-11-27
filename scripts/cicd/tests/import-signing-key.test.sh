#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2317,SC2329

set -euo pipefail

# Test suite for the release signing key import and check. Each test stubs gpg
# and gpgconf, runs the script with a scratch home directory and checks the
# GnuPG and Git configuration it writes, how the secrets reach gpg and the
# diagnostics.
#
# Usage:
#   $ ./scripts/cicd/tests/import-signing-key.test.sh
#
# Options:
#   VERBOSE=true  # Show all the executed commands, default is 'false'

# ==============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/../../tests/test.lib.sh"

readonly EXIT_STATUS_LABEL='exit status'
readonly GUIDE_ANCHOR='docs/guides/template/Publish_releases.md#signing-key-import-failed'
readonly BOT_ADDRESS='release-bot@example.com'
readonly BOT_LABEL='Release Bot'
readonly KEY_VALUE='-----BEGIN PGP PRIVATE KEY BLOCK-----TESTKEYMATERIAL-----END PGP PRIVATE KEY BLOCK-----'
readonly PASSPHRASE_VALUE='correct-horse-battery-staple'
readonly FINGERPRINT='0123456789ABCDEF0123456789ABCDEF01234567'
readonly OTHER_FINGERPRINT='89ABCDEF0123456789ABCDEF0123456789ABCDEF'

# Set up the suite and run every test.
function main() {

  cd "$(git rev-parse --show-toplevel)"

  # The caller's options must not reach the code under test
  unset -v GITHUB_ACTIONS GPG_PRIVATE_KEY GPG_PASSPHRASE BOT_NAME BOT_EMAIL GNUPGHOME

  test-run-suite \
    test-import-configures-git-signing \
    test-import-configures-gnupg-for-loopback \
    test-import-selects-key-by-bot-email \
    test-import-passes-secrets-on-stdin \
    test-import-hides-secrets-from-child-environments \
    test-import-never-prints-secrets \
    test-import-fails-when-import-fails \
    test-import-fails-without-matching-key \
    test-import-selects-first-matching-key \
    test-import-fails-when-unlock-fails \
    test-import-rejects-missing-inputs

  return 0
}

# ==============================================================================

function test-import-configures-git-signing() {

  # Arrange
  import-set-up
  # Act
  import-run
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-equal '' "$TEST_STDERR" 'no diagnostics'
  assert-equal "$BOT_LABEL" "$(import-git-config user.name)" 'user.name'
  assert-equal "$BOT_ADDRESS" "$(import-git-config user.email)" 'user.email'
  assert-equal "$FINGERPRINT" "$(import-git-config user.signingkey)" 'user.signingkey'
  assert-equal true "$(import-git-config commit.gpgsign)" 'commit.gpgsign'
  assert-equal gpg "$(import-git-config gpg.program)" 'gpg.program'
  assert-contains "$TEST_STDOUT" "$FINGERPRINT" 'fingerprint reported'

  return 0
}

function test-import-configures-gnupg-for-loopback() {

  # Arrange
  import-set-up
  # Act
  import-run
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-equal 700 "$(stat -c %a "$IMPORT_HOME/.gnupg" 2> /dev/null || stat -f %Lp "$IMPORT_HOME/.gnupg")" 'GnuPG home mode'
  assert-file-has-line "$IMPORT_HOME/.gnupg/gpg.conf" 'pinentry-mode loopback'
  assert-file-has-line "$IMPORT_HOME/.gnupg/gpg-agent.conf" 'allow-loopback-pinentry'
  assert-file-has-line "$IMPORT_HOME/.gnupg/gpg-agent.conf" 'default-cache-ttl 3600'
  assert-file-has-line "$IMPORT_HOME/.gnupg/gpg-agent.conf" 'max-cache-ttl 3600'
  # The agent restarts with this configuration before the passphrase is cached
  assert-equal 'gpgconf --kill gpg-agent' "$(grep -m 1 -e gpgconf -e '--detach-sign' "$TEST_TMP/order")" 'agent restarted first'
  # A later restart would drop the cached passphrase, so commits could not sign
  assert-equal 1 "$(grep -c gpgconf "$TEST_TMP/order")" 'agent restarted once'
  assert-equal '' "$(sed -n '/--detach-sign/,$p' "$TEST_TMP/order" | grep gpgconf)" 'no restart after the warm-up'

  return 0
}

function test-import-selects-key-by-bot-email() {

  # Arrange
  import-set-up
  # Act
  import-run
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-stub-called gpg "--batch --with-colons --list-secret-keys -- \\<$BOT_ADDRESS\\>"
  assert-contains "$(test-stub-calls gpg)" "--local-user $FINGERPRINT" 'warm-up uses the selected key'

  return 0
}

function test-import-passes-secrets-on-stdin() {

  # Arrange
  import-set-up
  # Act
  import-run
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-equal "$KEY_VALUE" "$(< "$TEST_TMP/import.stdin")" 'key read from stdin'
  assert-equal "$PASSPHRASE_VALUE" "$(< "$TEST_TMP/sign.stdin")" 'passphrase read from stdin'
  assert-contains "$(test-stub-calls gpg)" '--pinentry-mode loopback --passphrase-fd 0' 'loopback pinentry'
  assert-not-contains "$(test-stub-calls gpg)" 'TESTKEYMATERIAL' 'key not in argv'
  assert-not-contains "$(test-stub-calls gpg)" "$PASSPHRASE_VALUE" 'passphrase not in argv'

  return 0
}

function test-import-hides-secrets-from-child-environments() {

  # Arrange
  import-set-up
  # Act
  import-run
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-contains "$(< "$TEST_TMP/child.env")" 'HOME=' 'environments recorded'
  assert-not-contains "$(< "$TEST_TMP/child.env")" 'TESTKEYMATERIAL' 'key not inherited'
  assert-not-contains "$(< "$TEST_TMP/child.env")" "$PASSPHRASE_VALUE" 'passphrase not inherited'

  return 0
}

function test-import-never-prints-secrets() {

  # Arrange
  import-set-up
  local outcome
  for outcome in success import-fails sign-fails; do
    rm -f "$TEST_TMP/import-fails" "$TEST_TMP/sign-fails"
    [[ "$outcome" == success ]] || touch "$TEST_TMP/$outcome"
    # Act
    import-run
    # Assert
    assert-not-contains "$TEST_STDOUT$TEST_STDERR" 'TESTKEYMATERIAL' "key hidden ($outcome)"
    assert-not-contains "$TEST_STDOUT$TEST_STDERR" "$PASSPHRASE_VALUE" "passphrase hidden ($outcome)"
  done

  return 0
}





function test-import-fails-when-import-fails() {

  # Arrange
  import-set-up
  touch "$TEST_TMP/import-fails"
  # Act
  import-run
  # Assert
  import-assert-failure 'could not be imported'

  return 0
}

function test-import-fails-without-matching-key() {

  # Arrange
  import-set-up
  : > "$TEST_TMP/listing"
  # Act
  import-run
  # Assert
  import-assert-failure "has no secret key for the email '$BOT_ADDRESS'"

  return 0
}


function test-import-selects-first-matching-key() {

  # Arrange
  import-set-up
  import-listing "$FINGERPRINT" "$OTHER_FINGERPRINT"
  # Act
  import-run
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-equal "$FINGERPRINT" "$(import-git-config user.signingkey)" 'first matching key'

  return 0
}

function test-import-fails-when-unlock-fails() {

  # Arrange
  import-set-up
  touch "$TEST_TMP/sign-fails"
  # Act
  import-run
  # Assert
  import-assert-failure 'could not be unlocked with the passphrase'

  return 0
}

function test-import-rejects-missing-inputs() {

  # Arrange
  import-set-up
  # Act
  import-run GPG_PRIVATE_KEY= GPG_PASSPHRASE= BOT_NAME= BOT_EMAIL=
  # Assert
  import-assert-failure 'GIT_SIGNING_BOT_GPG_PRIVATE_KEY (or NHS_GIT_SIGNING_BOT_GPG_PRIVATE_KEY)'
  assert-contains "$TEST_STDERR" 'GIT_SIGNING_BOT_GPG_PASSPHRASE (or NHS_GIT_SIGNING_BOT_GPG_PASSPHRASE)' 'passphrase named'
  assert-contains "$TEST_STDERR" 'GIT_SIGNING_BOT_NAME (or NHS_GIT_SIGNING_BOT_NAME)' 'name named'
  assert-contains "$TEST_STDERR" 'GIT_SIGNING_BOT_EMAIL (or NHS_GIT_SIGNING_BOT_EMAIL)' 'email named'
  assert-stub-not-called gpg

  local missing name
  while read -r missing name; do
    # Act
    import-run "$missing"
    # Assert
    import-assert-failure "$name"
    assert-stub-not-called gpg
  done <<'CASES'
GPG_PRIVATE_KEY= GIT_SIGNING_BOT_GPG_PRIVATE_KEY
GPG_PASSPHRASE= GIT_SIGNING_BOT_GPG_PASSPHRASE
BOT_NAME= GIT_SIGNING_BOT_NAME
BOT_EMAIL= GIT_SIGNING_BOT_EMAIL
CASES

  return 0
}

# ==============================================================================

# Isolate PATH, keep git and stat, and stub gpg and gpgconf. The gpg stub saves
# the stdin of import and sign calls, prints "$TEST_TMP/listing" for listing
# calls and fails a call when "$TEST_TMP/<import|sign>-fails" exists. Both
# stubs append their environment to "$TEST_TMP/child.env" and their arguments
# to "$TEST_TMP/order".
function import-set-up() {

  test-isolate-path stat
  IMPORT_HOME="$TEST_TMP/home"
  mkdir -p "$IMPORT_HOME"
  import-listing "$FINGERPRINT"
  # shellcheck disable=SC2016
  test-stub gpg 'env >> "$TEST_TMP/child.env"
printf "gpg %s\n" "$*" >> "$TEST_TMP/order"
case " $* " in
  *" --import "*)
    printf "%s" "$(cat)" > "$TEST_TMP/import.stdin"
    if [[ -f "$TEST_TMP/import-fails" ]]; then
      echo "gpg: no valid OpenPGP data found." >&2
      exit 2
    fi
    ;;
  *" --list-secret-keys "*)
    cat "$TEST_TMP/listing"
    ;;
  *" --detach-sign "*)
    printf "%s" "$(cat)" > "$TEST_TMP/sign.stdin"
    if [[ -f "$TEST_TMP/sign-fails" ]]; then
      echo "gpg: signing failed: Bad passphrase" >&2
      exit 2
    fi
    echo "-----BEGIN PGP SIGNATURE-----"
    ;;
  *) exit 4 ;;
esac'
  # shellcheck disable=SC2016
  test-stub gpgconf 'env >> "$TEST_TMP/child.env"
printf "gpgconf %s\n" "$*" >> "$TEST_TMP/order"'
  IMPORT_ENV=(
    GPG_PRIVATE_KEY="$KEY_VALUE"
    GPG_PASSPHRASE="$PASSPHRASE_VALUE"
    BOT_NAME="$BOT_LABEL"
    BOT_EMAIL="$BOT_ADDRESS"
    HOME="$IMPORT_HOME"
  )

  return 0
}

# Write a canned secret key listing with one key per fingerprint.
# Arguments:
#   $@=[fingerprints]
function import-listing() {

  local fingerprint
  : > "$TEST_TMP/listing"
  for fingerprint in "$@"; do
    printf '%s\n' \
      "sec:u:255:22:${fingerprint: -16}:1700000000:::u:::scESC:::+:::ed25519:::0:" \
      "fpr:::::::::$fingerprint:" \
      "uid:u::::1700000000::0011223344556677::$BOT_LABEL <$BOT_ADDRESS>::::::::::0:" \
      "ssb:u:255:18:76543210FEDCBA98:1700000000::::::e:::+:::cv25519::" \
      'fpr:::::::::76543210FEDCBA9876543210FEDCBA9876543210:' \
      >> "$TEST_TMP/listing"
  done

  return 0
}

# Print a value from the Git global configuration the script wrote.
# Arguments:
#   $1=[key]
function import-git-config() {

  local key="$1"
  git config --file "$IMPORT_HOME/.gitconfig" --get "$key" || true

  return 0
}

# Run the script with the default environment and capture its output.
# Arguments:
#   $@=[optional environment assignments that replace or add variables]
function import-run() {

  rm -f "$STUB_DIR/gpg.calls" "$IMPORT_HOME/.gitconfig"
  test-capture env -i PATH="$PATH" TEST_TMP="$TEST_TMP" STUB_DIR="$STUB_DIR" LC_ALL=C \
    GIT_CONFIG_NOSYSTEM=1 "${IMPORT_ENV[@]}" "$@" "$TEST_REPO_ROOT/scripts/cicd/import-signing-key.sh"

  return 0
}

# Fail unless the run failed with an error that holds the text and links the
# guide, and Git was not set up to sign.
# Arguments:
#   $1=[expected text]
function import-assert-failure() {

  local text="$1"
  assert-equal 1 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-contains "$TEST_STDERR" 'ERROR:' 'error'
  assert-contains "$TEST_STDERR" "$text" 'error text'
  assert-contains "$TEST_STDERR" "$GUIDE_ANCHOR" 'guide link'
  assert-equal '' "$(import-git-config commit.gpgsign)" 'signing not configured'

  return 0
}

# ==============================================================================

main "$@"

exit 0
