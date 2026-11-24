#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2317,SC2329

set -euo pipefail

# Integration test suite for the release commit plugin
# scripts/cicd/semantic-release-api-commit.mjs. The setup installs
# semantic-release and the plugins pinned in the publish workflow from the npm
# registry. Each test runs a real semantic-release against a local test remote,
# with a GraphQL stub that stands in for GitHub and creates the commit there.
#
# Usage:
#   $ ./scripts/cicd/tests/release-api-commit.test.sh
#
# Options:
#   VERBOSE=true  # Show all the executed commands, default is 'false'
#
# Exit codes:
#   77 - npm is missing or cannot install the pinned packages, for example
#        without network access, so nothing is verified

# ==============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/../../tests/test.lib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/semantic-release.test-lib.sh"

# The implementation this plugin replaced, kept to prove the commit is
# unchanged
readonly RETIRED_GIT_PLUGIN='@semantic-release/git@11.0.1'
readonly PLUGIN="$TEST_REPO_ROOT/scripts/cicd/semantic-release-api-commit.mjs"
readonly STUB="$TEST_REPO_ROOT/scripts/cicd/tests/fixtures/graphql-stub.mjs"
readonly REPOSITORY=nhs-england-tools/example
readonly FIXTURE_DATE='2026-01-01T00:00:00Z'
readonly HEADLINE='chore(release): 1.1.0 [skip actions]'
readonly EXIT_STATUS_LABEL='exit status'
readonly NO_TAG_LABEL='no v1.1.0 tag'
readonly TAG='v1.1.0^{commit}'

# Set up the suite and run every test.
function main() {

  cd "$(git rev-parse --show-toplevel)"

  # The caller's options must not reach the code under test
  unset -v GITHUB_ACTIONS CI GITHUB_TOKEN GH_TOKEN GITHUB_REPOSITORY \
    GITHUB_GRAPHQL_URL STUB_MODE RELEASE_ENV

  test-run-suite \
    test-release-commits-version-through-the-api \
    test-release-commit-matches-the-git-plugin \
    test-release-notes-are-passed-verbatim \
    test-release-fails-closed-when-main-moved \
    test-release-fails-closed-when-the-api-rejects-the-token \
    test-release-reports-a-commit-it-cannot-fetch \
    test-release-does-not-follow-redirects \
    test-release-reports-an-uncertain-server-error \
    test-plugin-imports-only-node-built-ins \
    test-release-skips-the-commit-when-version-is-unchanged \
    test-dry-run-rejects-incomplete-settings

  return 0
}

# Install the pinned packages and the retired plugin once for every test.
function test-suite-setup() {

  local semantic exec preset
  semantic="$(workflow-pin 'SEMANTIC_RELEASE_VERSION: ' '')" || return 1
  exec="$(workflow-pin '' '@semantic-release\/exec@')" || return 1
  preset="$(workflow-pin '' 'conventional-changelog-conventionalcommits@')" || return 1
  semantic-release-install "semantic-release@$semantic" "@semantic-release/exec@$exec" \
    "conventional-changelog-conventionalcommits@$preset" "$RETIRED_GIT_PLUGIN" || return "$?"

  return 0
}

# ==============================================================================

function test-release-commits-version-through-the-api() {

  # Arrange
  local old request oid
  release-fixture 1.0.0
  old="$(git -C "$TEST_TMP/remote.git" rev-parse main)"
  # Act
  test-capture release-with-stub ok
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-equal 1 "$(wc -l < "$TEST_TMP/requests.log" | tr -d ' ')" 'one request'
  request="$(< "$TEST_TMP/requests.log")"
  assert-equal 'bearer test-token' "$(jq -r .authorization <<< "$request")" 'authorization header'
  assert-equal "$REPOSITORY" "$(jq -r .body.variables.input.branch.repositoryNameWithOwner <<< "$request")" 'repository'
  assert-equal main "$(jq -r .body.variables.input.branch.branchName <<< "$request")" 'branch'
  assert-equal "$old" "$(jq -r .body.variables.input.expectedHeadOid <<< "$request")" 'expected head'
  assert-equal "[{\"path\":\"VERSION\",\"contents\":\"$(jq -nr '"1.1.0\n" | @base64')\"}]" \
    "$(jq -c .body.variables.input.fileChanges.additions <<< "$request")" 'additions'
  assert-equal "$HEADLINE" "$(jq -r .body.variables.input.message.headline <<< "$request")" 'headline'
  assert-equal 1 "$(git -C "$TEST_TMP/remote.git" rev-list --count "$old..main")" 'one new commit on main'
  oid="$(jq -r .oid <<< "$request")"
  assert-equal "$oid" "$(git -C "$TEST_TMP/remote.git" rev-parse main)" 'remote main'
  assert-equal "$oid" "$(git -C "$TEST_TMP/remote.git" rev-parse "$TAG")" 'remote tag'
  assert-equal "$oid" "$(git -C "$TEST_TMP/repo" rev-parse HEAD)" 'local HEAD'
  assert-equal 'release-app[bot]' "$(git -C "$TEST_TMP/remote.git" log -1 --format=%an main)" 'author'
  assert-contains "$TEST_STDOUT" "Created the GitHub-signed release commit $oid." 'success log'

  return 0
}

function test-release-commit-matches-the-git-plugin() {

  # Arrange
  local message tree parent paths raw sent
  release-fixture 1.0.0
  release-config "${RETIRED_GIT_PLUGIN%@*}"
  test-capture semantic-release-run "$TEST_TMP/repo" "file://$TEST_TMP/remote.git"
  assert-equal 0 "$TEST_STATUS" "retired plugin $EXIT_STATUS_LABEL: $TEST_STDERR"
  message="$(git -C "$TEST_TMP/remote.git" log -1 --format=%B v1.1.0)"
  tree="$(git -C "$TEST_TMP/remote.git" rev-parse 'v1.1.0^{tree}')"
  parent="$(git -C "$TEST_TMP/remote.git" rev-parse 'v1.1.0^')"
  paths="$(git -C "$TEST_TMP/remote.git" diff --name-only 'v1.1.0^' v1.1.0)"
  # The raw message without the newline 'git commit' ends it with, kept exact
  # by a sentinel
  raw="$(git -C "$TEST_TMP/remote.git" cat-file commit v1.1.0 | sed '1,/^$/d'; printf .)"
  raw="${raw%.}"
  raw="${raw%$'\n'}"
  release-fixture 1.0.0
  # Act
  test-capture release-with-stub ok
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-equal VERSION "$paths" 'retired plugin changed paths'
  assert-equal "$message" "$(git -C "$TEST_TMP/remote.git" log -1 --format=%B v1.1.0)" 'message'
  assert-equal "$tree" "$(git -C "$TEST_TMP/remote.git" rev-parse 'v1.1.0^{tree}')" 'tree'
  assert-equal "$parent" "$(git -C "$TEST_TMP/remote.git" rev-parse 'v1.1.0^')" 'parent'
  assert-equal "$paths" "$(git -C "$TEST_TMP/remote.git" diff --name-only 'v1.1.0^' v1.1.0)" 'changed paths'
  sent="$(jq -j '.body.variables.input.message | .headline + "\n\n" + .body' < "$TEST_TMP/requests.log"; printf .)"
  assert-equal "$raw" "${sent%.}" 'message sent byte for byte'

  return 0
}

function test-release-notes-are-passed-verbatim() {

  # Arrange
  local text
  text="add \`\$(touch \"$TEST_TMP/pwned\")\` and ‘quotes’"
  release-fixture 1.0.0 "feat: $text"
  # Act
  test-capture release-with-stub ok
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-contains "$(jq -r .body.variables.input.message.body < "$TEST_TMP/requests.log")" "$text" 'notes in body'
  assert-file-not-exists "$TEST_TMP/pwned"

  return 0
}

function test-release-fails-closed-when-main-moved() {

  # Arrange
  local old
  release-fixture 1.0.0
  old="$(git -C "$TEST_TMP/remote.git" rev-parse main)"
  # Act
  test-capture release-with-stub stale
  # Assert
  assert-not-equal-zero "$TEST_STATUS"
  assert-contains "$TEST_STDERR" 'moved after this run started' 'stale error'
  assert-no-release-tag
  assert-equal "$old" "$(git -C "$TEST_TMP/remote.git" rev-parse main)" 'remote main unchanged'

  return 0
}

function test-release-fails-closed-when-the-api-rejects-the-token() {

  # Arrange
  release-fixture 1.0.0
  # Act
  test-capture release-with-stub unauthorised
  # Assert
  assert-not-equal-zero "$TEST_STATUS"
  assert-contains "$TEST_STDERR" 'release App' 'permission hint'
  assert-not-contains "$TEST_STDERR" test-token 'no token in stderr'
  assert-not-contains "$TEST_STDOUT" test-token 'no token in stdout'
  # semantic-release masks a leaked token as '[secure]'
  assert-not-contains "$TEST_STDERR$TEST_STDOUT" '[secure]' 'no masked token'
  assert-no-release-tag

  return 0
}

function test-release-reports-a-commit-it-cannot-fetch() {

  # Arrange
  release-fixture 1.0.0
  # Act
  test-capture release-with-stub phantom
  # Assert
  assert-not-equal-zero "$TEST_STATUS"
  assert-contains "$TEST_STDERR" 'the-tag-does-not-exist' 'runbook link'
  assert-contains "$TEST_STDERR" '0123456789abcdef' 'commit oid'
  assert-no-release-tag
  assert-contains "$(< "$TEST_TMP/git-trace.log")" 'fetch --quiet --no-tags' 'fetch attempted'

  # Arrange
  release-fixture 1.0.0
  # Act
  test-capture release-with-stub malformed
  # Assert
  assert-not-equal-zero "$TEST_STATUS"
  assert-contains "$TEST_STDERR" 'unexpected' 'malformed error'
  assert-file-not-exists "$TEST_TMP/repo/pwned"
  assert-no-release-tag
  assert-not-contains "$(< "$TEST_TMP/git-trace.log")" 'fetch --quiet --no-tags' 'no fetch attempted'

  return 0
}

function test-release-does-not-follow-redirects() {

  # Arrange
  release-fixture 1.0.0
  # Act
  test-capture release-with-stub redirect
  # Assert
  assert-not-equal-zero "$TEST_STATUS"
  assert-equal /graphql "$(jq -r .url < "$TEST_TMP/requests.log")" 'only the GraphQL request reached the stub'
  assert-contains "$TEST_STDERR" 'cannot tell whether GitHub created it' 'redirect refused'
  assert-equal '' "$(jq -r 'select(.url == "/captured") | .url' < "$TEST_TMP/requests.log")" 'no captured request'
  assert-no-release-tag

  return 0
}

function test-release-reports-an-uncertain-server-error() {

  # Arrange
  release-fixture 1.0.0
  # Act
  test-capture release-with-stub servererror
  # Assert
  assert-not-equal-zero "$TEST_STATUS"
  assert-contains "$TEST_STDERR" 'cannot tell whether GitHub created it' 'uncertain outcome'
  assert-not-contains "$TEST_STDERR" 'nothing was released' 'no false claim'
  assert-no-release-tag

  return 0
}

function test-plugin-imports-only-node-built-ins() {

  # Arrange
  local source specifiers specifier pattern
  source="$(< "$PLUGIN")"
  # Act
  specifiers="$(grep -oE "(from|^import) +['\"][^'\"]*['\"]" <<< "$source" | sed -E "s/^(from|import) +['\"]//; s/['\"]\$//")"
  # Assert
  assert-matches "$specifiers" '.' 'at least one import'
  while IFS= read -r specifier; do
    assert-matches "$specifier" '^node:' "import '$specifier' is a node: built-in"
  done <<< "$specifiers"
  for pattern in 'eval(' 'new Function' 'import(' 'node:vm' 'shell:' 'execSync(' 'spawn('; do
    assert-not-contains "$source" "$pattern" "no '$pattern'"
  done

  return 0
}

function test-release-skips-the-commit-when-version-is-unchanged() {

  # Arrange
  local head
  release-fixture 1.1.0
  head="$(git -C "$TEST_TMP/remote.git" rev-parse main)"
  # Act
  test-capture release-with-stub ok
  # Assert
  assert-equal 0 "$TEST_STATUS" "$EXIT_STATUS_LABEL: $TEST_STDERR"
  assert-file-not-exists "$TEST_TMP/requests.log"
  assert-contains "$TEST_STDOUT" 'No release assets changed, so no release commit is created.' 'skip log'
  assert-equal "$head" "$(git -C "$TEST_TMP/remote.git" rev-parse "$TAG")" 'tag on the pre-release head'

  return 0
}

function test-dry-run-rejects-incomplete-settings() {

  # Arrange
  local asset
  release-fixture 1.0.0
  # Act
  RELEASE_ENV=()
  test-capture semantic-release-run "$TEST_TMP/repo" "file://$TEST_TMP/remote.git" --dry-run
  # Assert
  assert-not-equal-zero "$TEST_STATUS"
  assert-contains "$TEST_STDERR" GITHUB_TOKEN 'missing token'
  assert-contains "$TEST_STDERR" GITHUB_REPOSITORY 'missing repository'

  # Arrange
  ln -s VERSION "$TEST_TMP/repo/link"
  printf '%s\n' /link >> "$TEST_TMP/repo/.git/info/exclude"
  # shellcheck disable=SC2016 # The placeholder is literal on purpose
  release-config "$PLUGIN" '{assets: ["*.txt", "../x", "/etc/passwd", "link"], message: "${branch.name}"}'
  RELEASE_ENV=(GITHUB_TOKEN=test-token "GITHUB_REPOSITORY=$REPOSITORY")
  # Act
  test-capture semantic-release-run "$TEST_TMP/repo" "file://$TEST_TMP/remote.git" --dry-run
  # Assert
  assert-not-equal-zero "$TEST_STATUS"
  for asset in '*.txt' '../x' '/etc/passwd' 'link' 'branch.name'; do
    assert-contains "$TEST_STDERR" "$asset" "names '$asset'"
  done

  # Arrange
  release-config "$PLUGIN"
  RELEASE_ENV=(GITHUB_TOKEN=test-token "GITHUB_REPOSITORY=$REPOSITORY" GITHUB_GRAPHQL_URL=http://example.invalid/graphql)
  # Act
  test-capture semantic-release-run "$TEST_TMP/repo" "file://$TEST_TMP/remote.git" --dry-run
  # Assert
  assert-not-equal-zero "$TEST_STATUS"
  assert-contains "$TEST_STDERR" GITHUB_GRAPHQL_URL 'names the endpoint setting'
  assert-contains "$TEST_STDERR" https 'requires https'

  return 0
}

# ==============================================================================

# Create "$TEST_TMP/repo" with VERSION '1.0.0' released as 'v1.0.0', then one
# commit that adds widget.txt and sets VERSION, and the bare test remote
# "$TEST_TMP/remote.git". Commit dates are fixed, so rebuilding the fixture at
# the same paths gives the same commits. Use the release commit plugin.
# Arguments:
#   $1=[VERSION content after the second commit]
#   $2=[subject of the second commit, default is 'feat: add widget']
function release-fixture() {

  local version="$1" subject="${2:-feat: add widget}" repo="$TEST_TMP/repo"
  test-isolate-path jq node
  rm -rf "$repo" "$TEST_TMP/remote.git" "$TEST_TMP/requests.log" "$TEST_TMP/port" "$TEST_TMP/git-trace.log"
  git init -q -b main "$repo"
  mkdir -p "$repo/.git/info"
  printf '%s\n' /.releaserc >> "$repo/.git/info/exclude"
  printf '1.0.0\n' > "$repo/VERSION"
  git -C "$repo" add VERSION
  GIT_AUTHOR_DATE="$FIXTURE_DATE" GIT_COMMITTER_DATE="$FIXTURE_DATE" \
    git -C "$repo" commit -q -m 'feat: first release'
  git -C "$repo" tag v1.0.0
  printf 'widget\n' > "$repo/widget.txt"
  printf '%s\n' "$version" > "$repo/VERSION"
  git -C "$repo" add widget.txt VERSION
  GIT_AUTHOR_DATE="$FIXTURE_DATE" GIT_COMMITTER_DATE="$FIXTURE_DATE" \
    git -C "$repo" commit -q -m "$subject"
  git clone -q --bare "$repo" "$TEST_TMP/remote.git"
  release-config "$PLUGIN"

  return 0
}

# Write the fixture's '.releaserc' from the repository file, without the
# GitHub plugin and with the given release commit plugin.
# Arguments:
#   $1=[release commit plugin name or path]
#   $2=[jq expression for its configuration, default is the repository's]
function release-config() {

  local plugin="$1" config="${2:-.}"
  jq --arg plugin "$plugin" '.plugins |= map(
      select(. != "@semantic-release/github")
      | if type == "array" and (.[0] == "@semantic-release/git" or (.[0] | endswith("semantic-release-api-commit.mjs")))
        then [$plugin, (.[1] | '"$config"')] else . end)' \
    "$TEST_REPO_ROOT/.releaserc" > "$TEST_TMP/releaserc"
  jq -e --arg plugin "$plugin" '[.plugins[] | select(type == "array" and .[0] == $plugin)] | length == 1' \
    "$TEST_TMP/releaserc" > /dev/null
  mv "$TEST_TMP/releaserc" "$TEST_TMP/repo/.releaserc"

  return 0
}

# Start the GraphQL stub, stop it when the shell exits, and run a release with
# the stub as the GraphQL endpoint. Git commands are traced to
# "$TEST_TMP/git-trace.log". Call it through test-capture.
# Arguments:
#   $1=[STUB_MODE]
#   $@=[extra semantic-release arguments]
function release-with-stub() {

  local mode="$1" port i
  shift
  STUB_MODE="$mode" node "$STUB" "$TEST_TMP/remote.git" "$TEST_TMP/port" "$TEST_TMP/requests.log" \
    > "$TEST_TMP/stub.log" 2>&1 &
  STUB_PID=$!
  trap 'kill "$STUB_PID" 2> /dev/null || :' EXIT
  for ((i = 0; i < 100; i++)); do
    [[ -s "$TEST_TMP/port" ]] && break
    sleep 0.1
  done
  if [[ ! -s "$TEST_TMP/port" ]]; then
    print-diagnostic error "The GraphQL stub did not start within 10 seconds, so the release did not run. Its output: $(< "$TEST_TMP/stub.log")"
    return 1
  fi
  port="$(< "$TEST_TMP/port")"
  RELEASE_ENV=(GITHUB_TOKEN=test-token "GITHUB_REPOSITORY=$REPOSITORY"
    "GITHUB_GRAPHQL_URL=http://127.0.0.1:$port/graphql" "GIT_TRACE=$TEST_TMP/git-trace.log")
  semantic-release-run "$TEST_TMP/repo" "file://$TEST_TMP/remote.git" "$@" || return "$?"

  return 0
}

# Fail unless the status is not zero.
# Arguments:
#   $1=[exit status]
function assert-not-equal-zero() {

  local status="$1"
  assert-matches "$status" '^[1-9][0-9]*$' "non-zero exit status: $TEST_STDERR"

  return 0
}

# Fail if the local repository or the remote has the tag 'v1.1.0'.
function assert-no-release-tag() {

  assert-equal '' "$(git -C "$TEST_TMP/remote.git" tag -l v1.1.0)" "remote $NO_TAG_LABEL"
  assert-equal '' "$(git -C "$TEST_TMP/repo" tag -l v1.1.0)" "local $NO_TAG_LABEL"

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
