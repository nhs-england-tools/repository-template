// Test double for the GitHub GraphQL createCommitOnBranch mutation. It
// listens on 127.0.0.1 on a free port, writes the port to <port-file> and
// appends every request as one JSON line to <request-log>. STUB_MODE picks the
// answer: ok, stale, unauthorised, phantom, malformed, redirect or servererror.
//
// Usage:
//   $ STUB_MODE=ok node graphql-stub.mjs <bare-repo> <port-file> <request-log>

import { execFileSync } from "node:child_process";
import { appendFileSync, renameSync, rmSync, writeFileSync } from "node:fs";
import { createServer } from "node:http";

const [bareRepo, portFile, requestLog] = process.argv.slice(2);
const mode = process.env.STUB_MODE ?? "ok";
const indexFile = `${requestLog}.index`;
const bot = {
  GIT_AUTHOR_NAME: "release-app[bot]",
  GIT_AUTHOR_EMAIL: "release-app@example.invalid",
  GIT_COMMITTER_NAME: "release-app[bot]",
  GIT_COMMITTER_EMAIL: "release-app@example.invalid",
};

function git(args, options = {}) {
  return execFileSync("git", ["--git-dir", bareRepo, ...args], {
    encoding: "utf8",
    ...options,
    env: { ...process.env, ...options.env },
  }).trim();
}

function createCommit(input) {
  const branch = input.branch.branchName;
  const head = git([
    "rev-parse",
    "--verify",
    "--end-of-options",
    `refs/heads/${branch}`,
  ]);
  if (input.expectedHeadOid !== head) {
    return [
      200,
      {
        errors: [
          {
            type: "STALE_DATA",
            message: `Expected branch to point to "${input.expectedHeadOid}" but it did not`,
          },
        ],
      },
    ];
  }
  const env = { GIT_INDEX_FILE: indexFile };
  git(["read-tree", head], { env });
  for (const { path, contents } of input.fileChanges.additions) {
    const blob = git(["hash-object", "-w", "--stdin"], {
      input: Buffer.from(contents, "base64"),
    });
    git(["update-index", "--add", "--cacheinfo", `100644,${blob},${path}`], {
      env,
    });
  }
  const tree = git(["write-tree"], { env });
  rmSync(indexFile, { force: true });
  const { headline, body } = input.message;
  const message = body ? `${headline}\n\n${body}` : headline;
  const oid = git(["commit-tree", tree, "-p", head, "-F", "-"], {
    input: message,
    env: bot,
  });
  git(["update-ref", `refs/heads/${branch}`, oid, head]);
  return [
    200,
    {
      data: {
        createCommitOnBranch: {
          commit: { oid, url: `https://github.invalid/commit/${oid}` },
        },
      },
    },
  ];
}

function fakeCommit(oid) {
  return [
    200,
    {
      data: {
        createCommitOnBranch: {
          commit: { oid, url: "https://github.invalid/commit" },
        },
      },
    },
  ];
}

function answer(request, input, port) {
  if (request.url === "/captured") return [418, { message: "captured" }];
  switch (mode) {
    case "ok":
      return createCommit(input);
    case "stale":
      return [
        200,
        {
          errors: [
            {
              type: "STALE_DATA",
              message: 'Expected branch to point to "0000000" but it did not',
            },
          ],
        },
      ];
    case "unauthorised":
      return [401, { message: "Bad credentials" }];
    case "phantom":
      return fakeCommit("0123456789abcdef0123456789abcdef01234567");
    case "malformed":
      return fakeCommit("--upload-pack=touch pwned");
    case "servererror":
      return [502, { message: "Bad Gateway" }];
    case "redirect":
      return [
        307,
        { message: "moved" },
        { location: `http://127.0.0.1:${port}/captured` },
      ];
    default:
      return [500, { message: `unknown STUB_MODE ${mode}` }];
  }
}

const server = createServer((request, response) => {
  const chunks = [];
  request.on("data", (chunk) => chunks.push(chunk));
  request.on("end", () => {
    const raw = Buffer.concat(chunks).toString("utf8");
    let body = raw;
    try {
      body = JSON.parse(raw);
    } catch {
      // The raw text is logged instead
    }
    let status;
    let payload;
    let headers = {};
    try {
      [status, payload, headers = {}] = answer(
        request,
        body?.variables?.input,
        server.address().port,
      );
    } catch (error) {
      [status, payload] = [500, { message: String(error) }];
    }
    const oid = payload?.data?.createCommitOnBranch?.commit?.oid ?? null;
    appendFileSync(
      requestLog,
      `${JSON.stringify({ method: request.method, url: request.url, authorization: request.headers.authorization ?? null, body, status, oid })}\n`,
    );
    response.writeHead(status, {
      "content-type": "application/json",
      ...headers,
    });
    response.end(JSON.stringify(payload));
  });
});

server.listen(0, "127.0.0.1", () => {
  writeFileSync(`${portFile}.tmp`, `${server.address().port}\n`);
  renameSync(`${portFile}.tmp`, portFile);
});
