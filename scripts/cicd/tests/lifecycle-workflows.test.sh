#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2317,SC2329

set -euo pipefail

# Run the CI/CD lifecycle command blocks against a project Makefile fixture.
# Check that each target runs and that its failure fails the workflow step.
#
# Usage:
#   $ ./scripts/cicd/tests/lifecycle-workflows.test.sh
#
# Options:
#   VERBOSE=true  # Show all the executed commands, default is 'false'

# ==============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/../../tests/test.lib.sh"

readonly REMOVE_WHITESPACE='s/[[:space:]]//g'

# Run every lifecycle workflow test.
function main() {

  cd "$(git rev-parse --show-toplevel)"

  test-run-suite \
    test-repository-version-script-prints-the-version \
    test-repository-version-script-rejects-invalid-versions \
    test-metadata-reads-the-repository-version-without-generating-files \
    test-metadata-ignores-stale-image-versions \
    test-metadata-rejects-missing-or-invalid-repository-versions \
    test-build-workflow-runs-project-build \
    test-publish-workflow-runs-project-publish \
    test-deploy-workflow-runs-project-deploy \
    test-deploy-rejects-unprotected-tags \
    test-deploy-runs-the-commit-the-tag-resolves-to \
    test-publish-credentials-include-fallbacks \
    test-publish-release-is-signed-by-github \
    test-publish-plan-uses-one-authenticated-dry-run \
    test-publish-release-reports-the-semantic-release-tag \
    test-publish-plan-blocks-artefacts-on-check-failures \
    test-lifecycle-workflows-propagate-target-failures

  return 0
}

# ==============================================================================

function test-repository-version-script-prints-the-version() {

  # Arrange
  metadata-prepare
  printf '%s\n' 1.2.3 > VERSION
  # Act
  test-capture ./scripts/cicd/read-repository-version.sh
  # Assert
  assert-equal 0 "$TEST_STATUS" "version script: $TEST_STDERR"
  assert-equal 1.2.3 "$TEST_STDOUT" 'repository version'
  assert-equal '' "$TEST_STDERR" 'no diagnostics'

  return 0
}

function test-repository-version-script-rejects-invalid-versions() {

  # Arrange
  metadata-prepare
  local version
  for version in missing '' unknown 01.2.3 $'1.2.3\n9.9.9'; do
    if [[ "$version" == missing ]]; then
      rm -f VERSION
    else
      printf '%s\n' "$version" > VERSION
    fi
    # Act
    test-capture env GITHUB_ACTIONS=true ./scripts/cicd/read-repository-version.sh
    # Assert
    assert-equal 1 "$TEST_STATUS" 'invalid VERSION'
    assert-equal '' "$TEST_STDOUT" 'no version returned'
    assert-contains "$TEST_STDERR" '::error::'
    assert-contains "$TEST_STDERR" 'VERSION'
  done

  return 0
}

function test-metadata-reads-the-repository-version-without-generating-files() {

  # Arrange
  metadata-prepare
  local workflow version
  for workflow in cicd-1-pull-request.yaml cicd-3-deploy.yaml; do
    for version in 0.0.0 1.2.3; do
      printf '%s\n' "$version" > VERSION
      # Act
      metadata-run "$workflow"
      # Assert
      assert-equal 0 "$TEST_STATUS" "$workflow metadata: $TEST_STDERR"
      assert-equal "version=$version" \
        "$(sed -n '/^version=/p' "$TEST_TMP/output")" 'repository version output'
      assert-file-not-exists .version
    done
  done

  return 0
}

function test-metadata-ignores-stale-image-versions() {

  # Arrange
  metadata-prepare
  printf '%s\n' 1.2.3 > VERSION
  printf '%s\n' 9.9.9 > .version
  local workflow
  for workflow in cicd-1-pull-request.yaml cicd-3-deploy.yaml; do
    # Act
    metadata-run "$workflow"
    # Assert
    assert-equal 0 "$TEST_STATUS" "$workflow metadata: $TEST_STDERR"
    assert-equal 'version=1.2.3' \
      "$(sed -n '/^version=/p' "$TEST_TMP/output")" 'repository version output'
    assert-equal 9.9.9 "$(cat .version)" 'image version is left untouched'
  done

  return 0
}

function test-metadata-rejects-missing-or-invalid-repository-versions() {

  # Arrange
  metadata-prepare
  printf '%s\n' 9.9.9 > .version
  local workflow version
  for workflow in cicd-1-pull-request.yaml cicd-3-deploy.yaml; do
    for version in missing '' unknown 01.2.3 $'1.2.3\n9.9.9'; do
      if [[ "$version" == missing ]]; then
        rm -f VERSION
      else
        printf '%s\n' "$version" > VERSION
      fi
      # Act
      metadata-run "$workflow"
      # Assert
      assert-equal 1 "$TEST_STATUS" "$workflow rejects invalid VERSION"
      assert-equal '' "$(sed -n '/^version=/p' "$TEST_TMP/output")" \
        'invalid version is not exported'
      assert-contains "$TEST_STDERR" 'VERSION'
    done
  done

  return 0
}

# shellcheck disable=SC2016 # GitHub expressions, not shell ones
function test-publish-plan-uses-one-authenticated-dry-run() {

  # Arrange
  local workflow=.github/workflows/cicd-2-publish.yaml
  # Act
  local token_condition permissions dry_run token version due
  token_condition="$(yq -r '.jobs.plan.steps[] | select(.id == "app-token") | .if // ""' "$workflow")"
  permissions="$(yq -r '.jobs.plan.steps[] | select(.id == "app-token") | .with
    | to_entries[] | select(.key | test("^permission-")) | .key + "=" + .value' "$workflow")"
  dry_run="$(yq -r '.jobs.plan.steps[] | select(.id == "verify") | .with.dry_run' "$workflow")"
  token="$(yq -r '.jobs.plan.steps[] | select(.id == "verify") | .env.GITHUB_TOKEN' "$workflow")"
  version="$(yq -r '.jobs.plan.outputs.version' "$workflow")"
  due="$(yq -r '.jobs.plan.outputs.release' "$workflow")"
  # Assert
  assert-equal '' "$token_condition" 'token is available before the dry run'
  assert-equal 'permission-contents=write' "$permissions" 'dry run proves push access only'
  assert-equal true "$dry_run" 'planning is a dry run'
  assert-equal '${{ steps.app-token.outputs.token }}' "$token" 'dry run uses the App token'
  assert-equal '${{ steps.verify.outputs.new_release_version }}' "$version" 'artefacts use the dry-run version'
  assert-equal '${{ steps.verify.outputs.new_release_published }}' "$due" 'only planned releases publish'

  return 0
}

# shellcheck disable=SC2016 # GitHub expressions, not shell ones
function test-publish-release-reports-the-semantic-release-tag() {

  # Arrange
  test-isolate-path yq
  local workflow=.github/workflows/cicd-2-publish.yaml plan release
  # Act
  plan="$(yq -o=json -I=0 '.jobs.plan.steps[] | select(.id == "verify") | [.uses, .with.semantic_version, .with.extra_plugins]' "$workflow")"
  release="$(yq -o=json -I=0 '.jobs.release.steps[] | select(.id == "semantic-release") | [.uses, .with.semantic_version, .with.extra_plugins]' "$workflow")"
  # Assert
  assert-equal "$plan" "$release" 'plan and release run the same semantic-release'
  assert-equal '${{ steps.semantic-release.outputs.new_release_git_tag }}' \
    "$(yq -r '.jobs.release.outputs.tag' "$workflow")" 'notification uses the released tag'
  assert-equal '${{ steps.semantic-release.outputs.new_release_version }}' \
    "$(yq -r '.jobs.release.outputs.version' "$workflow")" 'notification uses the released version'

  return 0
}

function test-deploy-rejects-unprotected-tags() {

  # Arrange
  local commands tag
  commands="$(yq -r '.jobs.metadata.steps[] | select(.id == "tag") | .run' \
    .github/workflows/cicd-3-deploy.yaml)"
  for tag in candidate v1 v1.2 v1.2.3-rc.1 v01; do
    # Act
    test-capture env TAG="$tag" GITHUB_OUTPUT="$TEST_TMP/output" bash -e -c "$commands"
    # Assert
    assert-equal 1 "$TEST_STATUS" "reject $tag"
  done
  for tag in v1.2.3 v0.2.3; do
    # Act
    test-capture env TAG="$tag" GITHUB_OUTPUT="$TEST_TMP/output" bash -e -c "$commands"
    # Assert
    assert-equal 0 "$TEST_STATUS" "accept $tag"
  done

  return 0
}

# shellcheck disable=SC2016 # GitHub expressions, not shell ones
function test-deploy-runs-the-commit-the-tag-resolves-to() {

  # Arrange
  test-isolate-path yq
  local workflow=.github/workflows/cicd-3-deploy.yaml metadata deploy
  # Act
  metadata="$(yq -r '.jobs.metadata.steps[] | select(.name == "📥 Checkout code") | .with.ref' "$workflow")"
  deploy="$(yq -r '.jobs.deploy.steps[] | select(.name == "📥 Checkout code") | .with.ref' "$workflow")"
  # Assert
  assert-equal 'refs/tags/${{ steps.tag.outputs.tag }}' "$metadata" 'tag checkout'
  assert-equal '${{ steps.variables.outputs.commit }}' \
    "$(yq -r '.jobs.metadata.outputs.commit' "$workflow")" 'resolved commit output'
  assert-equal '${{ needs.metadata.outputs.commit }}' "$deploy" 'deployed commit'
  assert-equal 'read' "$(yq -r '.jobs.metadata.permissions.contents' "$workflow")" 'read-only permissions'

  return 0
}


# shellcheck disable=SC2016 # GitHub expressions, not shell ones
function test-publish-credentials-include-fallbacks() {

  # Arrange
  test-isolate-path yq
  local workflow=.github/workflows/cicd-2-publish.yaml input context setting plan release
  local token_query='.jobs[strenv(JOB)].steps[] | select(.id == "app-token") | .with[strenv(INPUT)]'
  while read -r input context setting; do
    # Act
    plan="$(JOB=plan INPUT="$input" yq -r "$token_query" "$workflow" | sed "$REMOVE_WHITESPACE")"
    release="$(JOB=release INPUT="$input" yq -r "$token_query" "$workflow" | sed "$REMOVE_WHITESPACE")"
    # Assert
    assert-equal "$release" "$plan" "plan and release use the same $input"
    assert-equal "\${{$context.$setting||$context.NHS_$setting}}" "$release" "$input uses an NHS fallback"
  done <<'INPUTS'
app-id vars GH_VERSIONING_RELEASE_APP_ID
private-key secrets GH_VERSIONING_RELEASE_APP_PRIVATE_KEY
INPUTS
  # Assert
  assert-equal '${{ steps.app-token.outputs.token }}' \
    "$(yq -r '.jobs.release.steps[] | select(.id == "semantic-release") | .env.GITHUB_TOKEN' "$workflow")" 'release uses the App token'

  return 0
}

# shellcheck disable=SC2016 # GitHub expressions, not shell ones
function test-publish-release-is-signed-by-github() {

  # Arrange
  test-isolate-path yq
  local workflow=.github/workflows/cicd-2-publish.yaml
  local plugin=./scripts/cicd/semantic-release-api-commit.mjs
  local names identity plugins order
  # Act
  names="$(yq -r '.jobs.release.steps[].name' "$workflow")"
  identity="$(yq -r '.jobs.release.steps[] | select(.id == "semantic-release") | .env | keys | .[]' "$workflow" \
    | grep -E '^GIT_(AUTHOR|COMMITTER)_' || true)"
  plugins="$(yq -r '.env.SEMANTIC_RELEASE_PLUGINS' "$workflow")"
  order="$(yq -r '.plugins[] | ((select(tag == "!!seq") | .[0]) // .)' .releaserc | grep -xF -e @semantic-release/exec -e "$plugin" -e @semantic-release/github)"
  # Assert
  assert-not-contains "$names" '🔑 Import the signing key'
  assert-equal '' "$identity" 'release sets no git identity'
  assert-equal '' "$(git grep -nE 'GPG_PRIVATE_KEY|GPG_PASSPHRASE|GIT_SIGNING_BOT' -- .github/workflows || true)" 'no signing references'
  assert-not-contains "$plugins" '@semantic-release/git@'
  assert-equal "@semantic-release/exec
$plugin
@semantic-release/github" "$order" 'plugin runs between exec and github'

  return 0
}

# shellcheck disable=SC2016 # GitHub expressions, not shell ones
function test-publish-plan-blocks-artefacts-on-check-failures() {

  # Arrange
  test-isolate-path yq
  local workflow=.github/workflows/cicd-2-publish.yaml token verify
  # Act
  token="$(yq -o=json -I=0 '.jobs.plan.steps[] | select(.id == "app-token")' "$workflow")"
  verify="$(yq -o=json -I=0 '.jobs.plan.steps[] | select(.id == "verify")' "$workflow")"
  # Assert
  assert-equal 'false' "$(yq -r '.continue-on-error // false' <<< "$token")" 'token failure fails the plan'
  assert-equal 'false' "$(yq -r '.continue-on-error // false' <<< "$verify")" 'dry-run failure fails the plan'
  assert-equal 'false' "$(yq -r '.jobs.plan.continue-on-error // false' "$workflow")" 'plan failure stops dependent jobs'
  assert-equal 'plan' "$(yq -r '.jobs.publish-artefacts.needs[] | select(. == "plan")' "$workflow")" 'publication needs plan'
  assert-equal "needs.plan.outputs.release == 'true'" "$(yq -r '.jobs.publish-artefacts.if' "$workflow")" 'publication requires release'

  return 0
}

function test-build-workflow-runs-project-build() {

  # Act
  lifecycle-run stage-3-build.yaml artefact-1 build
  # Assert
  assert-equal 0 "$TEST_STATUS" "build exit status: $TEST_STDERR"
  assert-equal build "$(cat "$TEST_TMP/result")" "project build ran"

  return 0
}

function test-publish-workflow-runs-project-publish() {

  # Act
  lifecycle-run cicd-2-publish.yaml publish-artefacts publish
  # Assert
  assert-equal 0 "$TEST_STATUS" "publish exit status: $TEST_STDERR"
  assert-equal publish "$(cat "$TEST_TMP/result")" "project publish ran"

  return 0
}

function test-deploy-workflow-runs-project-deploy() {

  # Act
  lifecycle-run cicd-3-deploy.yaml deploy deploy
  # Assert
  assert-equal 0 "$TEST_STATUS" "deploy exit status: $TEST_STDERR"
  assert-equal deploy "$(cat "$TEST_TMP/result")" "project deploy ran"

  return 0
}

function test-lifecycle-workflows-propagate-target-failures() {

  local workflow job target
  while read -r workflow job target; do
    # Act
    lifecycle-run "$workflow" "$job" "$target" "$target"
    # Assert
    assert-equal 2 "$TEST_STATUS" "$target failure exit status: $TEST_STDERR"
    assert-equal "" "$(cat "$TEST_TMP/result")" "$target did not complete"
  done <<'CASES'
stage-3-build.yaml artefact-1 build
cicd-2-publish.yaml publish-artefacts publish
cicd-3-deploy.yaml deploy deploy
CASES

  return 0
}

# ==============================================================================

# Prepare a repository checkout for the real metadata command blocks.
function metadata-prepare() {

  test-isolate-path yq make
  test-create-repo "$TEST_TMP/project" Makefile mise.toml
  ln -s "$TEST_REPO_ROOT/scripts" "$TEST_TMP/project/scripts"
  cd "$TEST_TMP/project"

  return 0
}

# Run the metadata variables step without inheriting the caller's environment.
# Arguments:
#   $1=[workflow file name]
function metadata-run() {

  local workflow="$1" commands
  commands="$(yq -r '.jobs.metadata.steps[] | select(.id == "variables") | .run' \
    "$TEST_REPO_ROOT/.github/workflows/$workflow")"
  : > "$TEST_TMP/output"
  test-capture env -i PATH="$PATH" GITHUB_OUTPUT="$TEST_TMP/output" \
    bash --noprofile --norc -eo pipefail -c "$commands"

  return 0
}

# Run a workflow step with real Make and isolated project targets.
# Arguments:
#   $1=[workflow file name]
#   $2=[job ID]
#   $3=[step ID and target name]
#   $4=[target to fail, default is empty]
function lifecycle-run() {

  local workflow="$1" job="$2" target="$3" fail_target="${4:-}" commands
  test-isolate-path yq make
  commands="$(JOB="$job" STEP="$target" yq -r \
    '.jobs[strenv(JOB)].steps[] | select(.id == strenv(STEP)) | .run' \
    "$TEST_REPO_ROOT/.github/workflows/$workflow")"
  mkdir -p "$TEST_TMP/project"
  printf '%s\n' \
    '.PHONY: build publish deploy' \
    'build publish deploy:' \
    $'\t@test "$(FAIL_TARGET)" != "$@"' \
    $'\t@printf "%s\\n" "$@" >> "$(RESULT)"' \
    > "$TEST_TMP/project/Makefile"
  : > "$TEST_TMP/result"
  cd "$TEST_TMP/project"
  test-capture env -i PATH="$PATH" RESULT="$TEST_TMP/result" \
    FAIL_TARGET="$fail_target" bash --noprofile --norc -eo pipefail -c "$commands"

  return 0
}

# ==============================================================================

main "$@"

exit 0
