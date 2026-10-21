# Updating Dependencies

Keeping dependencies current brings security fixes and compatibility improvements. Exact pins and lockfiles make builds repeatable, while verified checksums, provenance and image digests help establish where downloaded software came from. Review updates and run the repository checks before merging them.

## Dependency Sources

- **mise tools and mise itself:** exact tool versions and the minimum mise CLI version are in [mise.toml](../../mise.toml). Resolved tool versions, checksums and supported provenance are recorded in [mise.lock](../../mise.lock) and `.mise/locks/`.
- **Docker images:** the custom `[_.docker]` table in [mise.toml](../../mise.toml) pins helper images by version tag and SHA-256 digest. Dockerfile base images are resolved from these entries by the Docker helpers.
- **GitHub Actions:** external actions are referenced in [workflow files](../../.github/workflows/) by full commit SHA, with a release tag comment. Workflows also select the GitHub-hosted runner image with `runs-on`.
- **Application packages:** the expected dependencies are Python and npm (TypeScript) packages, as these language ecosystems are supported by Engineering and approved on the Tech Radar. This template currently has no application dependency manifests. [Dependabot](../../.github/dependabot.yaml) is configured for npm (including pnpm) and uv if those manifests are added.
- **Host prerequisites:** the macOS GNU tools installed by [install-gnu-macos.sh](../../scripts/toolchain/install-gnu-macos.sh) are Homebrew-managed and are not version-pinned here.

The pre-commit configuration currently runs repository-owned Make targets. Its `pre-commit` executable is a mise tool, so there are no separate third-party hook revisions to update.

## Ground Rules

- **Wait seven days.** Updates applied by hand follow the same seven-day cooldown that mise (`minimum_release_age`) and Dependabot (`cooldown`) apply automatically. This covers the mise CLI, GitHub Actions and Docker tags. Pick the newest release published at least seven days ago, not the newest release, and check publish dates on the release page or with `gh release list`. Security fixes are the exception and need a reviewed decision.
- **Keep `[_.docker]` and `[tools]` in step.** Each Docker image that mirrors a mise tool must carry the same version as that tool. See [Docker Images](#docker-images).
- **An empty update is a valid result.** When every check below reports nothing to change, stop. The only expected `make toolchain-outdated` entry is `editorconfig-checker` 4.x, which is excluded deliberately.
- **Update everything in one pull request,** then verify once at the end.
- **Do not bypass the safeguards.** Do not shorten the cooldown with `MISE_MINIMUM_RELEASE_AGE` or `--minimum-release-age` outside the reviewed security exception. Do not edit `mise.lock` or the `.mise/locks/` sidecars by hand. mise writes these files, and Dependabot is configured to skip `.mise/`.
- **Stop on a checksum mismatch.** It means the downloaded bytes differ from the recorded artefact. Do not delete the lock entry or re-lock the tool to clear the error. Report it and investigate the upstream release first, see the mise [checksum mismatch guidance](https://mise.jdx.dev/dev-tools/mise-lock.html#checksum-mismatch).

## Updating Dependencies

### mise Tools

Check for updates, including major versions:

```shell
make toolchain-outdated
```

Preview and apply eligible updates:

```shell
make toolchain-upgrade dry_run=true
make toolchain-upgrade
```

The upgrade target updates `mise.toml` and refreshes the lock data. It excludes `editorconfig-checker` by default because version 4 removes the `ec` executable used by this repository. Review that tool separately before changing the exclusion. Commit `mise.toml`, `mise.lock` and any changed `.mise/locks/` sidecars together.

The configured `minimum_release_age = "7d"` delays newly published versions when mise resolves an update. Existing exact pins and versions already recorded in `mise.lock` are not delayed again. `locked_verify_provenance = true` asks mise to re-check supported provenance when installing locked tools. A lockfile checksum verifies downloaded bytes, but provenance is only available for tools whose upstream publishes verifiable attestations or signatures. See the [mise upgrade](https://mise.jdx.dev/cli/upgrade.html), [mise lockfile](https://mise.jdx.dev/dev-tools/mise-lock.html) and [mise security](https://mise.jdx.dev/security.html) references.

The mise CLI and project tools have separate update paths. To update both in one pull request:

1. Find the newest mise release that is at least seven days old and review its release notes.
2. Set `min_version` in `mise.toml` to that version. CI reads this value and installs exactly that mise version. A locally installed CLI that is newer than `min_version` is fine, so run `mise self-update` only if yours is older.
3. Check project tool updates with `make toolchain-outdated`, preview with `make toolchain-upgrade dry_run=true`, then apply with `make toolchain-upgrade`.
4. Update the matching `[_.docker]` entries for any tool that changed, see [Docker Images](#docker-images).
5. Run `make test` and `make lint`. Review the workflow results and the `mise.toml`, `mise.lock` and `.mise/locks/` changes together.

No Make target updates the CLI or `min_version`. See the [mise update instructions](https://mise.jdx.dev/installing-mise.html#updating).

### Docker Images

The `[_.docker]` table lets the scripts run the same tools in containers when they are not installed natively, so each image must run the same version as its mise tool. The `make toolchain-outdated` and `make toolchain-upgrade` targets do not touch `[_.docker]`, so after every `[tools]` change, update the images by hand.

**The rule:** the version in each `[_.docker]` entry equals the version of the matching `[tools]` entry, allowing for the image's tag spelling (for example a `v` prefix or a `-slim` suffix). The comment beside each pin names the matching tool. Tools with no `[_.docker]` entry need nothing. The Dockerfile base images are resolved from `[_.docker]` by [docker.lib.sh](../../scripts/docker/docker.lib.sh).

For each changed tool, find the matching image tag and obtain its digest:

```shell
docker buildx imagetools inspect IMAGE:TAG --format '{{.Manifest.Digest}}'
```

Set the entry in `mise.toml` to `TAG@sha256:DIGEST`. The digest, not the tag, fixes the image contents, and tags can be rebuilt after you pin them, so re-check the digest of an existing pin when auditing. Use the index digest this command prints, and check that it serves the repository's `linux/amd64` pulls. If the image for a new tool version does not exist yet, hold the tool at the previous version. See Docker's [digest guide](https://docs.docker.com/dhi/core-concepts/digests/) and [`imagetools inspect` reference](https://docs.docker.com/reference/cli/docker/buildx/imagetools/inspect/).

The `node` and `python` tools are in the template because Python and npm (TypeScript) are the supported and approved language ecosystems, so projects built from this template are expected to use them. The `node` image is also the Prettier runtime for the formatting checks, so keep it on the same version as the `node` tool.

Pull the revised pins and run the checks that use them:

```shell
make docker-pull-pinned-images
FORCE_USE_DOCKER=true make lint
FORCE_USE_DOCKER=true make test
```

The pull command checks that every pinned image is available. The forced runs are an optional smoke test that uses the pinned containers instead of locally installed tools, and exercises only the images used by lint and the formatting checks.

### GitHub Actions and Runners

Dependabot checks GitHub Actions daily, with a seven-day cooldown configured in [dependabot.yaml](../../.github/dependabot.yaml). It can update SHA-pinned actions when the same-line comment records the release tag. Review the proposed commit SHA and upstream release notes, and keep the full SHA and version comment together. GitHub recommends full-length commit SHA pins in its [workflow security guidance](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions).

For a manual update, find the newest release that is at least seven days old and read its release notes. For a major version bump, check each breaking change against how the workflows call the action. For example, `jdx/mise-action` v5 changed a default that has no effect here because the workflows set `version` explicitly. Resolve the release tag to its full commit SHA from the action's own repository, for example with `gh api repos/OWNER/REPO/commits/TAG -q .sha`. Then replace the SHA and the version comment together in every workflow that uses the action.

Dependabot does not generate vulnerability alerts for actions pinned to commit SHAs. Review Dependabot version-update pull requests and upstream security advisories.

Runner labels such as `ubuntu-26.04` are not action dependencies and are not updated by Dependabot. Check GitHub's [runner image releases](https://github.com/actions/runner-images/releases) and supported labels before changing `runs-on`.

### Application Packages

When application dependencies are added, keep the manifest and its lockfile together and use the ecosystem's package manager to update them. Dependabot's current npm and uv entries run daily and wait seven days before version updates. This cooldown does not delay security updates. Check the generated diff and run the relevant tests rather than editing a lockfile by hand.

### Homebrew Tools

The GNU prerequisites are listed in `scripts/toolchain/install-gnu-macos.sh` without version pins. Plain `brew outdated` lists every installed formula, so limit the check to the formulae in the script's `FORMULAE` array and update only those that are outdated:

```shell
brew outdated FORMULA...
brew upgrade FORMULA
```

Homebrew changes are local to your machine and are not part of the pull request.

## Verify the Update

Review all version, SHA, digest and lockfile changes. Confirm that every `[_.docker]` version matches its `[tools]` entry. Run the repository checks before merging:

```shell
make test
make lint
```
