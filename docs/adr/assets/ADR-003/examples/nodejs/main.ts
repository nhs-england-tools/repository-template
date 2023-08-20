import * as jwt from "jsonwebtoken";
import axios from "axios";
import * as fs from "fs";

interface Installation {
  id: number;
  account: {
    login: string;
  };
}

const ghAppId = process.env.GITHUB_APP_ID;
const ghAppPkFile = process.env.GITHUB_APP_PK_FILE;
const ghOrg = process.env.GITHUB_ORG;

if (!ghAppId || !ghAppPkFile || !ghOrg) {
  throw new Error(
    "Environment variables GITHUB_APP_ID, GITHUB_APP_PK_FILE and GITHUB_ORG must be passed to this program."
  );
}

function getJwtToken(ghAppId: string, ghAppPkFile: string): string {
  const signingKey = fs.readFileSync(ghAppPkFile, "utf8");
  const payload = {
    iat: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + 600,
    iss: ghAppId,
  };

  return jwt.sign(payload, signingKey, { algorithm: "RS256" });
}

async function getInstallationId(
  jwtToken: string,
  ghOrg: string
): Promise<number | null> {
  const headers = {
    Authorization: `Bearer ${jwtToken}`,
    Accept: "application/vnd.github.v3+json",
  };
  const response = await axios.get<Installation[]>(
    "https://api.github.com/app/installations",
    { headers }
  );
  const installation = response.data.find(
    (inst) => inst.account.login === ghOrg
  );

  return installation?.id || null;
}

async function getAccessToken(
  jwtToken: string,
  installationId: number
): Promise<string> {
  const headers = {
    Authorization: `Bearer ${jwtToken}`,
    Accept: "application/vnd.github.v3+json",
  };
  const response = await axios.post<{ token: string }>(
    `https://api.github.com/app/installations/${installationId}/access_tokens`,
    {},
    { headers }
  );

  return response.data.token;
}

(async () => {
  const jwtToken = getJwtToken(ghAppId, ghAppPkFile);
  const installationId = await getInstallationId(jwtToken, ghOrg);
  if (!installationId) {
    console.log(`No installation found for organization ${ghOrg}`);
    return;
  }
  const accessToken = await getAccessToken(jwtToken, installationId);

  console.log(`GITHUB_TOKEN=${accessToken}`);
})();
