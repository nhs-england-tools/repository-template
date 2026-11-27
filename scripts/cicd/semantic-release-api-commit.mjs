// semantic-release plugin that creates the release commit through the GitHub
// GraphQL createCommitOnBranch mutation, so GitHub signs it. It replaces the
// prepare step of @semantic-release/git and keeps its commit message, tree and
// parent. It uses Node built-ins only and never runs a shell.

import { execFileSync } from "node:child_process";
import { existsSync, lstatSync, readFileSync, realpathSync } from "node:fs";
import { isAbsolute, relative, resolve } from "node:path";

const RUNBOOK = "docs/guides/template/Publish_releases.md";
const DEFAULT_GRAPHQL_URL = "https://api.github.com/graphql";
const TIMEOUT_MS = 30_000;
const MAX_RESPONSE_BYTES = 1024 * 1024;
const MAX_DETAIL_LENGTH = 200;
const GIT_PATHS = ["/usr/bin/git", "/bin/git"];
const TRAILING_SPACE = new Set([" ", "\t", "\v", "\f", "\r"]);
const OID = /^[0-9a-f]{40}$/;
const REPOSITORY = /^[A-Za-z0-9-]+\/[A-Za-z0-9._-]+$/;
const BRANCH = /^[A-Za-z0-9._/-]+$/;
const GLOB = /[*?[\]{}!]/;
const PLACEHOLDER = /\$\{([^}]*)\}/g;
const VERSION_PLACEHOLDER = "nextRelease.version";
const NOTES_PLACEHOLDER = "nextRelease.notes";
const MUTATION = `mutation ($input: CreateCommitOnBranchInput!) {
  createCommitOnBranch(input: $input) { commit { oid url } }
}`;

/**
 * Check the plugin settings and fail with every problem found.
 * @param {{ assets?: unknown, message?: unknown }} pluginConfig
 * @param {object} context semantic-release context
 * @returns {Promise<void>}
 */
export async function verifyConditions(pluginConfig, context) {
  const { problems } = readSettings(pluginConfig, context);
  if (problems.length > 0) throw settingsError(problems);
}

/**
 * Create the release commit on GitHub and check it out, so semantic-release
 * tags it.
 * @param {{ assets?: unknown, message?: unknown }} pluginConfig
 * @param {object} context semantic-release context
 * @returns {Promise<void>}
 */
export async function prepare(pluginConfig, context) {
  const settings = readSettings(pluginConfig, context);
  if (settings.problems.length > 0) throw settingsError(settings.problems);
  const { cwd, logger, nextRelease } = context;
  const branch = context.branch.name;
  const gitHead = nextRelease.gitHead;
  const git = gitRunner(cwd, context.env);

  if (!OID.test(String(gitHead))) {
    throw new Error(
      `semantic-release gave no valid commit to release on \`${branch}\`, so nothing was released. Use Re-run failed jobs. See ${RUNBOOK}#release-step-failed`,
    );
  }
  if (git(["rev-parse", "--show-prefix"]).trim() !== "") {
    throw new Error(
      `semantic-release runs outside the repository's top-level directory, so the release commit cannot be created and nothing was released. Run it from the top-level directory. See ${RUNBOOK}#release-step-failed`,
    );
  }

  const changed = changedAssets(git, settings.assets);
  if (changed.length === 0) {
    logger.log("No release assets changed, so no release commit is created.");
    return;
  }
  const additions = changed.map((path) => ({
    path,
    contents: readAsset(cwd, path).toString("base64"),
  }));
  const { headline, body } = splitMessage(
    cleanUp(render(settings.message, nextRelease)),
  );
  if (headline.includes("\n")) {
    throw new Error(
      `The release commit message has no one-line headline, so nothing was released. Put a single line before the first blank line of 'message'. See ${RUNBOOK}#release-settings-are-missing`,
    );
  }

  const oid = await createCommit(settings, {
    branch: {
      repositoryNameWithOwner: settings.repository,
      branchName: branch,
    },
    message: { headline, body },
    expectedHeadOid: gitHead,
    fileChanges: { additions },
  });
  checkOut(git, context.options.repositoryUrl, branch, gitHead, oid);
  logger.log(`Created the GitHub-signed release commit ${oid}.`);
}

// ==============================================================================
// Settings

function readSettings(pluginConfig, context) {
  const env = context.env ?? {};
  const token = env.GITHUB_TOKEN || env.GH_TOKEN || "";
  const repository = env.GITHUB_REPOSITORY ?? "";
  const endpoint = env.GITHUB_GRAPHQL_URL || DEFAULT_GRAPHQL_URL;
  const { assets, message } = pluginConfig ?? {};
  const problems = [
    ...tokenProblems(token),
    ...repositoryProblems(repository),
    ...endpointProblems(endpoint),
    ...branchProblems(context.branch?.name),
    ...assetsProblems(context.cwd, assets),
    ...messageProblems(message),
  ];

  return { problems, token, repository, endpoint, assets, message };
}

function tokenProblems(token) {
  return token === "" ? ["GITHUB_TOKEN (or GH_TOKEN) is not set."] : [];
}

function repositoryProblems(repository) {
  if (REPOSITORY.test(repository)) return [];
  const state = repository === "" ? "not set" : "malformed";
  return [`GITHUB_REPOSITORY must be 'owner/name' but is ${state}.`];
}

function endpointProblems(endpoint) {
  if (isAllowedEndpoint(endpoint)) return [];
  return [
    "GITHUB_GRAPHQL_URL must be an https URL without credentials. Plain http is allowed only for 127.0.0.1.",
  ];
}

function branchProblems(branch) {
  if (typeof branch === "string" && BRANCH.test(branch) && !branch.includes(".."))
    return [];
  return ["The release branch name is not a plain branch name."];
}

function assetsProblems(cwd, assets) {
  if (!Array.isArray(assets) || assets.length === 0) {
    return ["'assets' must be a non-empty list of file paths."];
  }
  return assets.flatMap((asset) => {
    const problem = assetProblem(cwd, asset);
    return problem ? [`Asset ${JSON.stringify(asset)} ${problem}.`] : [];
  });
}

function messageProblems(message) {
  if (typeof message !== "string" || message.trim() === "") {
    return ["'message' must be a non-empty string."];
  }
  const problems = [];
  for (const [placeholder, name] of message.matchAll(PLACEHOLDER)) {
    if (name !== VERSION_PLACEHOLDER && name !== NOTES_PLACEHOLDER) {
      problems.push(
        `'message' has the unknown placeholder ${placeholder}. Only \${${VERSION_PLACEHOLDER}} and \${${NOTES_PLACEHOLDER}} are supported.`,
      );
    }
  }
  const { headline } = splitMessage(cleanUp(message));
  if (headline.includes("\n") || headline.includes(NOTES_PLACEHOLDER)) {
    problems.push(
      "'message' must start with a one-line headline without the release notes.",
    );
  }
  return problems;
}

function isAllowedEndpoint(value) {
  let url;
  try {
    url = new URL(value);
  } catch {
    return false;
  }
  if (url.username !== "" || url.password !== "") return false;
  return (
    url.protocol === "https:" ||
    (url.protocol === "http:" && url.hostname === "127.0.0.1")
  );
}

// Return why an asset is not acceptable, or nothing. A missing file is
// accepted here, because a prepare step may create it.
function assetProblem(cwd, asset) {
  if (typeof asset !== "string" || asset === "") return "is not a file path";
  if (isAbsolute(asset))
    return "is an absolute path, use a path relative to the repository";
  if (GLOB.test(asset)) return "has a glob character, list plain file paths";
  if (
    asset.startsWith(":") ||
    asset.includes("\\") ||
    /[\u0000-\u001f\u007f]/.test(asset)
  ) {
    return "has a character that is not allowed in an asset path";
  }
  if (
    asset
      .split("/")
      .some((part) => part === ".." || part === "." || part === "")
  ) {
    return "is not a normalised path inside the repository, remove '..', '.' and empty parts";
  }
  let stats;
  try {
    stats = lstatSync(resolve(cwd, asset));
  } catch (error) {
    return error.code === "ENOENT" ? undefined : "cannot be read";
  }
  if (!stats.isFile())
    return "is not a regular file, symbolic links are not allowed";
  if (!isInside(cwd, resolve(cwd, asset)))
    return "resolves outside the repository";
  return undefined;
}

function isInside(cwd, path) {
  const fromRoot = relative(realpathSync(cwd), realpathSync(path));
  return fromRoot !== "" && !fromRoot.startsWith("..") && !isAbsolute(fromRoot);
}

function settingsError(problems) {
  const list = problems.map((problem) => "- " + problem).join("\n");
  return new Error(
    `The release commit settings are incomplete, so nothing was released:\n${list}\nFix the release settings, then use Re-run failed jobs. See ${RUNBOOK}#release-settings-are-missing`,
  );
}

// ==============================================================================
// Release commit content

// Run git from a fixed, root-owned directory, so a writable PATH entry cannot
// put another git in its place.
function gitRunner(cwd, env) {
  const git = GIT_PATHS.find((path) => existsSync(path));
  if (!git) {
    throw new Error(
      `git was not found at ${GIT_PATHS.join(" or ")}, so the release commit cannot be created and nothing was released. Install git on the runner. See ${RUNBOOK}#release-step-failed`,
    );
  }
  return (args) =>
    execFileSync(git, args, {
      cwd,
      env: { ...env, GIT_TERMINAL_PROMPT: "0" },
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    });
}

function changedAssets(git, assets) {
  const output = git([
    "--literal-pathspecs",
    "status",
    "--porcelain=v1",
    "-z",
    "--untracked-files=all",
    "--",
    ...assets,
  ]);
  const entries = output.split("\0");
  const changed = new Set();
  for (let i = 0; i < entries.length; i++) {
    const entry = entries[i];
    if (entry.length < 4) continue;
    const status = entry.slice(0, 2);
    if (status.includes("D")) {
      throw new Error(
        `The release asset ${JSON.stringify(entry.slice(3))} was deleted. The release commit only adds or updates files, so nothing was released. Keep the asset in the repository. See ${RUNBOOK}#release-step-failed`,
      );
    }
    changed.add(entry.slice(3));
    if (status[0] === "R" || status[0] === "C") i++;
  }
  return assets.filter((asset) => changed.has(asset));
}

function readAsset(cwd, asset) {
  const path = resolve(cwd, asset);
  if (!lstatSync(path).isFile() || !isInside(cwd, path)) {
    throw new Error(
      `The release asset ${JSON.stringify(asset)} is not a regular file inside the repository, so nothing was released. Fix 'assets' in the release settings. See ${RUNBOOK}#release-settings-are-missing`,
    );
  }
  return readFileSync(path);
}

// Replace the two supported placeholders literally, in one pass, so text in
// the release notes is never rendered again.
function render(template, nextRelease) {
  return template.replace(PLACEHOLDER, (placeholder, name) => {
    if (name === VERSION_PLACEHOLDER) return String(nextRelease.version ?? "");
    if (name === NOTES_PLACEHOLDER) return String(nextRelease.notes ?? "");
    return placeholder;
  });
}

// Tidy whitespace like 'git commit -m' does: drop trailing whitespace on each
// line, leading and trailing blank lines, and repeated blank lines.
function cleanUp(text) {
  const lines = [];
  let blank = false;
  for (const line of text.split("\n")) {
    const trimmed = trimTrailingSpace(line);
    if (trimmed === "") {
      blank = lines.length > 0;
      continue;
    }
    if (blank) lines.push("");
    blank = false;
    lines.push(trimmed);
  }
  return lines.join("\n");
}

// Drop the whitespace 'git commit -m' drops at a line end, in linear time.
function trimTrailingSpace(line) {
  let end = line.length;
  while (end > 0 && TRAILING_SPACE.has(line[end - 1])) end--;
  return line.slice(0, end);
}

function splitMessage(message) {
  const index = message.indexOf("\n\n");
  if (index === -1) return { headline: message, body: "" };
  return { headline: message.slice(0, index), body: message.slice(index + 2) };
}

// ==============================================================================
// GitHub API

async function createCommit(settings, input) {
  const branch = input.branch.branchName;
  let status;
  let text;
  try {
    const response = await fetch(settings.endpoint, {
      method: "POST",
      headers: {
        authorization: `bearer ${settings.token}`,
        "content-type": "application/json",
        accept: "application/json",
      },
      body: JSON.stringify({ query: MUTATION, variables: { input } }),
      redirect: "error",
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
    status = response.status;
    text = await readCapped(response);
  } catch (error) {
    const detail = redact(
      settings.token,
      [error?.name, error?.cause?.code ?? error?.cause?.message]
        .filter(Boolean)
        .join(": "),
    );
    throw new Error(
      `The request to GitHub to create the release commit on \`${branch}\` failed (${detail}), so this job cannot tell whether GitHub created it. No tag was created. Check \`${branch}\` for a release commit before you rerun. See ${RUNBOOK}#release-step-failed`,
    );
  }

  let json;
  try {
    json = JSON.parse(text);
  } catch {
    json = undefined;
  }
  const errors = Array.isArray(json?.errors) ? json.errors : [];
  const types = errors.map((error) => String(error?.type ?? ""));
  const messages = errors.map((error) => String(error?.message ?? ""));

  if (status === 401 || status === 403 || types.includes("FORBIDDEN")) {
    throw new Error(
      `GitHub refused the release App's request to create the release commit on \`${branch}\` (HTTP ${status}), so nothing was released. Check that the release App is installed on the repository, has contents read and write permission and is on the bypass list of the \`${branch}\` ruleset. Then use Re-run failed jobs. See ${RUNBOOK}#release-app`,
    );
  }
  if (
    types.includes("STALE_DATA") ||
    messages.some((message) => message.includes("Expected branch to point to"))
  ) {
    throw new Error(
      `\`${branch}\` moved after this run started, so GitHub did not create the release commit and nothing was released. The newer publish run releases it. See ${RUNBOOK}#release-step-failed`,
    );
  }
  if (status >= 500) {
    throw new Error(
      `GitHub answered the request to create the release commit on \`${branch}\` with HTTP ${status}, so this job cannot tell whether GitHub created it. No tag was created. Check \`${branch}\` for a release commit before you rerun. See ${RUNBOOK}#release-step-failed`,
    );
  }
  if (status !== 200 || errors.length > 0) {
    const type = types[0] ? `, ${types[0]}` : "";
    const message = json?.message ?? messages[0];
    const detail = message
      ? `: ${redact(settings.token, String(message))}`
      : "";
    throw new Error(
      `GitHub did not create the release commit on \`${branch}\` (HTTP ${status}${type}${detail}), so nothing was released. Fix the cause, then use Re-run failed jobs. See ${RUNBOOK}#release-step-failed`,
    );
  }

  const oid = json?.data?.createCommitOnBranch?.commit?.oid;
  if (typeof oid !== "string" || !OID.test(oid)) {
    throw new Error(
      `GitHub returned an unexpected response to the release commit request, so this job cannot tell whether GitHub created it. No tag was created. Check \`${branch}\` for a release commit before you rerun. See ${RUNBOOK}#release-step-failed`,
    );
  }
  return oid;
}

async function readCapped(response) {
  const chunks = [];
  let size = 0;
  if (response.body) {
    for await (const chunk of response.body) {
      size += chunk.byteLength;
      if (size > MAX_RESPONSE_BYTES)
        throw new Error("response larger than 1 MiB");
      chunks.push(chunk);
    }
  }
  return Buffer.concat(chunks).toString("utf8");
}

// Keep only printable text, without the token, cut to 200 characters.
function redact(token, text) {
  let clean = String(text).replace(/[\u0000-\u001f\u007f]+/g, " ");
  if (token) clean = clean.split(token).join("[token]");
  return clean.slice(0, MAX_DETAIL_LENGTH);
}

// ==============================================================================
// Local checkout

function checkOut(git, repositoryUrl, branch, gitHead, oid) {
  try {
    git([
      "fetch",
      "--quiet",
      "--no-tags",
      "--",
      repositoryUrl,
      `refs/heads/${branch}`,
    ]);
    git(["cat-file", "-e", "--end-of-options", `${oid}^{commit}`]);
    const parent = git([
      "rev-parse",
      "--verify",
      "--end-of-options",
      `${oid}^`,
    ]).trim();
    if (parent !== gitHead) throw new Error("unexpected parent");
    git(["reset", "--hard", "--quiet", "--end-of-options", oid]);
  } catch {
    // The cause may hold the authenticated repository URL, so it is dropped
    throw new Error(
      `GitHub created the release commit \`${oid}\` on \`${branch}\`, but this job could not check it out, so no tag was created. Do not rerun. Follow ${RUNBOOK}#the-tag-does-not-exist`,
    );
  }
}
