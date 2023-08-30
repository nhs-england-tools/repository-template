// import * as jwt from "jsonwebtoken";
// import axios from "axios";
// import * as fs from "fs";

// import { Octokit: restOctokit } from "@octokit/rest";
import { App, Octokit } from "octokit";

export const getOctokit = async (
  privateKey: string,
  appId: string,
  organisationName: string
): Promise<Octokit> => {
  const app = new App({ appId, privateKey });
  let installationId = -9999;
  app.eachInstallation((d) => {
    //@ts-ignore
    if (d.installation.account?.login == organisationName) {
      console.log("MADE IT HERE", d.installation.id);
      installationId = d.installation.id;
      return app.getInstallationOctokit(installationId);
    }
  });
};

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

(async () => {
  const octokit = await getOctokit(ghAppPkFile, ghAppId, ghOrg);
  // const repos = await octokit.request("GET /repos/{owner}", {
  //   owner: ghOrg,
  // });
  // console.log(repos);
  // do some stuff with repos
})();
