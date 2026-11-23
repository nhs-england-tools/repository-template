#!/usr/bin/env bash

set -euo pipefail

# Import the release signing key and set up Git to sign commits with it, so
# semantic-release's release commit is signed without a prompt. It selects the
# first secret key with a user ID for the bot email, caches its passphrase in
# gpg-agent and sets the Git global user name, email and signing key. The
# publish workflow runs it in the 'release' job before semantic-release.
#
# Usage:
#   $ GPG_PRIVATE_KEY=... GPG_PASSPHRASE=... BOT_NAME='Release Bot' \
#       BOT_EMAIL=bot@example.com ./scripts/cicd/import-signing-key.sh
#
# Options:
#   GPG_PRIVATE_KEY=armoured-key
#       ASCII-armoured secret key of the signing bot, required
#   GPG_PASSPHRASE=passphrase
#       Passphrase of that key, required
#   BOT_NAME='Release Bot'
#       Name of the signing bot, used only to set up Git, required
#   BOT_EMAIL=bot@example.com
#       Email of the signing bot, required
#   GNUPGHOME=path
#       GnuPG home to import into, default is '$HOME/.gnupg'
#
# Exit codes:
#   0 - Git signs commits with the key
#   1 - An option is missing, or the key cannot be imported, found or unlocked
#
# Notes:
#   1) The key reaches gpg on stdin, and the passphrase through loopback
#      pinentry on stdin, never as arguments that 'ps' could show. Only the
#      first line of the passphrase is used. Both secrets are removed from the
#      environment first, so no child process inherits them. gpg's own output
#      is discarded.
#   2) There is no VERBOSE option, because tracing would print the secrets.
#   3) gpg-agent caches the passphrase for an hour, longer than the release
#      job may run, so Git signs from the cache. One signature of an empty
#      payload fills the cache. The agent is restarted before the import, so it
#      reads that setting.

# ==============================================================================

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/github-actions.lib.sh"

readonly GUIDE_LINK='docs/guides/template/Publish_releases.md#signing-key-import-failed'
readonly KEY_NAMES='GIT_SIGNING_BOT_GPG_PRIVATE_KEY (or NHS_GIT_SIGNING_BOT_GPG_PRIVATE_KEY)'
readonly PASSPHRASE_NAMES='GIT_SIGNING_BOT_GPG_PASSPHRASE (or NHS_GIT_SIGNING_BOT_GPG_PASSPHRASE)'
readonly NAME_NAMES='GIT_SIGNING_BOT_NAME (or NHS_GIT_SIGNING_BOT_NAME)'
readonly EMAIL_NAMES='GIT_SIGNING_BOT_EMAIL (or NHS_GIT_SIGNING_BOT_EMAIL)'
readonly CACHE_SECONDS=3600

# Check the inputs, import the key, cache its passphrase and set up Git.
function main() {

  local key="${GPG_PRIVATE_KEY:-}" passphrase="${GPG_PASSPHRASE:-}"
  local name="${BOT_NAME:-}" email="${BOT_EMAIL:-}" fingerprint
  unset -v GPG_PRIVATE_KEY GPG_PASSPHRASE

  check-inputs "$key" "$passphrase" "$name" "$email" || return 1
  configure-gnupg || return 1
  if ! printf '%s\n' "$key" | gpg --batch --quiet --import > /dev/null 2>&1; then
    fail "The signing key from $KEY_NAMES could not be imported, so the release commit cannot be signed and nothing was released. Export the key again with 'gpg --armor --export-secret-keys' and update the secret, then use 'Re-run failed jobs'."
    return 1
  fi
  fingerprint="$(select-key "$email")"
  if [[ -z "$fingerprint" ]]; then
    fail "The signing key from $KEY_NAMES has no secret key for the email '$email' from $EMAIL_NAMES, so the release commit cannot be signed and nothing was released. Set $EMAIL_NAMES to the key email, then use 'Re-run failed jobs'."
    return 1
  fi
  if ! printf '%s\n' "$passphrase" | gpg --batch --yes --pinentry-mode loopback --passphrase-fd 0 \
    --local-user "$fingerprint" --armor --detach-sign --output - /dev/null > /dev/null 2>&1; then
    fail "The signing key $fingerprint could not be unlocked with the passphrase from $PASSPHRASE_NAMES, so the release commit cannot be signed and nothing was released. Check the passphrase and that the key has not expired, then use 'Re-run failed jobs'."
    return 1
  fi
  git config --global user.name "$name"
  git config --global user.email "$email"
  git config --global user.signingkey "$fingerprint"
  git config --global gpg.program gpg
  git config --global commit.gpgsign true
  echo "Release commits are signed with the key $fingerprint as $name <$email>."

  return 0
}

# ==============================================================================

# Fail with an error naming every missing input.
# Arguments:
#   $1=[secret key]
#   $2=[passphrase]
#   $3=[bot name]
#   $4=[bot email]
function check-inputs() {

  local missing=''
  [[ -n "$1" ]] || missing+="${missing:+, }$KEY_NAMES"
  [[ -n "$2" ]] || missing+="${missing:+, }$PASSPHRASE_NAMES"
  [[ -n "$3" ]] || missing+="${missing:+, }$NAME_NAMES"
  [[ -n "$4" ]] || missing+="${missing:+, }$EMAIL_NAMES"
  if [[ -n "$missing" ]]; then
    fail "These release settings are empty: $missing. Without them the release commit cannot be signed, so nothing was released. Set them as repository or organisation secrets and variables, then use 'Re-run failed jobs'."
    return 1
  fi

  return 0
}

# Create the GnuPG home, readable by the owner only, allow loopback pinentry,
# cache the passphrase longer than the job runs, and restart the agent so it
# reads the settings.
function configure-gnupg() {

  local home="${GNUPGHOME:-$HOME/.gnupg}"
  mkdir -p "$home" || return 1
  chmod 700 "$home" || return 1
  printf '%s\n' 'pinentry-mode loopback' >> "$home/gpg.conf" || return 1
  printf '%s\n' allow-loopback-pinentry "default-cache-ttl $CACHE_SECONDS" "max-cache-ttl $CACHE_SECONDS" \
    >> "$home/gpg-agent.conf" || return 1
  if ! gpgconf --kill gpg-agent > /dev/null 2>&1; then
    fail "gpg-agent could not be restarted to read its settings, so the release commit may not be signed without a prompt and nothing was released. Use 'Re-run failed jobs' on a new runner."
    return 1
  fi

  return 0
}

# Print the fingerprint of the first secret key with a user ID for the email,
# or nothing when none matches. gpg matches an email in angle brackets exactly,
# in any case.
# Arguments:
#   $1=[bot email]
function select-key() {

  local listing
  listing="$(gpg --batch --with-colons --list-secret-keys -- "<$1>" 2> /dev/null)" || listing=''
  awk -F: '$1 == "fpr" { print $10; exit }' <<< "$listing"

  return 0
}

# Print an error that links the guide.
# Arguments:
#   $1=[message]
function fail() {

  print-diagnostic error "$1 See $GUIDE_LINK"

  return 0
}

# ==============================================================================

main "$@" || exit 1

exit 0
