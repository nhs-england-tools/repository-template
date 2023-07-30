# Guide: Scan dependencies

- [Guide: Scan dependencies](#guide-scan-dependencies)
  - [Overview](#overview)
  - [Key files](#key-files)
  - [Configuration checklist](#configuration-checklist)
  - [Testing](#testing)
  - [FAQ](#faq)

## Overview

In modern software development, leveraging third-party dependencies is a common practice to reduce redundancy and improve efficiency. However, this introduces potential security risks and compliance issues into our codebase, making dependency scanning crucial. This process helps identify known vulnerabilities, or Common Vulnerabilities and Exposures (CVEs), in third-party libraries, allowing us to mitigate security threats proactively. Regular CVE scanning strengthens our codebase's security, ensuring adherence to top-tier security standards. In addition, generating a Software Bill of Materials (SBOM) - a comprehensive inventory of software components, libraries, and modules - is a valuable practice. SBOMs enhance transparency and traceability, giving an overview of all software elements, their versions, and associated licenses. This facilitates effective dependency management, compliance assurance, and timely response to version-specific vulnerabilities.

[Syfy](https://github.com/anchore/syft) and [Grype](https://github.com/anchore/grype) are valuable tools that can bolster this process. Syft generates a detailed SBOM, ensuring full visibility and traceability of all incorporated software components. This facilitates precise tracking, management, and potential updating of dependencies. On the other hand, Grype, as a vulnerability scanner, meticulously examines dependencies for known CVEs, providing an extra layer of security and allowing us to rectify vulnerabilities promptly. By incorporating Syft and Grype into our CI/CD pipeline, we can ensure continuous scanning of dependencies and generate an up-to-date SBOM. This approach enables real-time detection and resolution of vulnerabilities, thereby fortifying our software development lifecycle against security risks and ensuring adherence to compliance requirements.

## Key files

- [generate-sbom.sh](../../scripts/generate-sbom.sh): A shell script that generates SBOM (Software Bill of Materials)
- [.syft.yaml](../../scripts/config/.syft.yaml): A configuration file for the SBOM generator
- [scan-vulnerabilities.sh](../../scripts/scan-vulnerabilities.sh): A shell script that performs CVE analysis
- [.grype.yaml](../../scripts/config/.grype.yaml): A configuration file for the CVE scanner
- [scan-dependencies.yaml](../../.github/workflows/scan-dependencies.yaml): GitHub action to run the scripts as part of the CI/CD pipeline
- [.gitignore](../../.gitignore): Excludes the `sbom-report*.json` and `vulnerabilities-report*.json` report files created during the process

## Configuration checklist

- [Adjust the configuration settings](../../scripts/config/.grype.yaml) to align with your project's specific requirements
- [Create a dependency baseline](https://github.com/anchore/grype#specifying-matches-to-ignore) for your repository excluding false-positives from the scanning process
- Make sure the GitHub action, which incorporates Syft and Grype, is part of your GitHub CI/CD workflow. More details on this can be found in the [NHSE Software Engineering Quality Framework](https://github.com/NHSDigital/software-engineering-quality-framework/blob/main/tools/dependency-scan/README.md)
- It is crucial to ensure that both, the SBOM and the vulnerabilities reports are uploaded to the central repository or a designated location for streamlined reporting and easy access. Here are the secret variables that has to be set for this functionality to work:
  - `IDP_AWS_ACCOUNT_ID` - the central AWS account ID where the reports will be uploaded; this will be set by a GitHub organization owner
  - `IDP_AWS_REGION` - the region of the AWS account; this will be set by a GitHub organization owner
  - `IDP_AWS_ROLE_NAME` - a dedicated role name for this repository that can authenticate to the central location for the purpose of uploading the reports
  - `IDP_SBOM_BUCKET_ENDPOINT` - this is a dedicated S3 bucket endpoint for uploading the reports
- If you have any queries about how to set this up, please contact either @stefaniuk or @andyblundell

## Testing

You can run and test the process locally on a developer's workstation using the following commands

SBOM generator

```shell
./scripts/generate-sbom.sh
cat sbom-report.json | jq
```

CVE scanner

```shell
./scripts/scan-vulnerabilities.sh
cat vulnerabilities-report.json | jq
```

## FAQ

1. _Why do we need to use all three tools: Syft, Grype, and Dependabot?_

   Syft, Grype, and Dependabot each serve unique functions in our CI/CD pipeline. Syft is used to generate a detailed Software Bill of Materials (SBOM), providing full visibility and traceability of all incorporated software components. Grype performs detailed scans of dependencies against the Common Vulnerabilities and Exposures (CVEs) list, adding an extra layer of security by introducing a quality gate in the delivery pipeline. Dependabot helps to keep your dependencies up-to-date and can also alert you to known vulnerabilities affecting your dependencies, showing the best path to resolution. By using all three, we ensure comprehensive dependency management is in place, from tracking and updating dependencies to identifying and rectifying found vulnerabilities.

2. _Why don't we use a GitHub Action already available on the GitHub Marketplace, or bundle this functionality into a single one?_

   While GitHub Actions are a key part of our CI/CD pipeline, they are not a standalone solution for dependency management. Syft, Grype, and Dependabot provide specialized functionalities that, although integrated into our pipeline through GitHub Actions, cannot be fully replaced by a single GitHub Action alone. By treating these tools as distinct components, we retain more flexibility in our configuration and can make more granular adjustments as needed. There are additional benefits, such as:

   - Transparency and visibility of the implementation
   - Ease of investigating CVEs found in the repository without depending on a third-party like GitHub
   - Portability and flexibility of running the scans in different environments
