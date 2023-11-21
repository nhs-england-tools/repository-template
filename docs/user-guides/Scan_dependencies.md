# Guide: Scan dependencies

- [Guide: Scan dependencies](#guide-scan-dependencies)
  - [Overview](#overview)
  - [Key files](#key-files)
  - [Configuration checklist](#configuration-checklist)
  - [Testing](#testing)
  - [FAQ](#faq)

## Overview

In modern software development, leveraging third-party dependencies is a common practice to reduce redundancy and improve efficiency. However, this introduces potential security risks and compliance issues into our codebase, making dependency scanning crucial. This process helps identify known vulnerabilities, or Common Vulnerabilities and Exposures (CVEs), in third-party libraries, allowing us to mitigate security threats proactively. Regular CVE scanning strengthens our codebase's security, ensuring adherence to top-tier security standards. In addition, generating a Software Bill of Materials (SBOM) - a comprehensive inventory of software components, libraries, and modules - is a valuable practice. SBOMs enhance transparency and traceability, giving an overview of all software elements, their versions, and associated licenses. This facilitates effective dependency management, compliance assurance, and timely response to version-specific vulnerabilities.

[Syft](https://github.com/anchore/syft) and [Grype](https://github.com/anchore/grype) are valuable tools that can bolster this process. Syft generates a detailed SBOM, ensuring full visibility and traceability of all incorporated software components. This facilitates precise tracking, management, and potential updating of dependencies. On the other hand, Grype, as a vulnerability scanner, meticulously examines dependencies for known CVEs, providing an extra layer of security and allowing us to rectify vulnerabilities promptly. By incorporating Syft and Grype into our CI/CD pipeline, we can ensure continuous scanning of dependencies and generate an up-to-date SBOM. This approach enables real-time detection and resolution of vulnerabilities, thereby fortifying our software development lifecycle against security risks and ensuring adherence to compliance requirements.

## Key files

- [`create-sbom-report.sh`](../../scripts/reports/create-sbom-report.sh): A shell script that generates SBOM (Software Bill of Materials)
- [`syft.yaml`](../../scripts/config/syft.yaml): A configuration file for the SBOM generator
- [`scan-vulnerabilities.sh`](../../scripts/reports/scan-vulnerabilities.sh): A shell script that performs CVE analysis
- [`grype.yaml`](../../scripts/config/grype.yaml): A configuration file for the CVE scanner
- [`scan-dependencies/action.yaml`](../../.github/actions/scan-dependencies/action.yaml): GitHub action to run the scripts as part of the CI/CD pipeline
- [`.gitignore`](../../.gitignore): Excludes the `*sbom*report.json` and `*vulnerabilities*report.json` report files created during the process

## Configuration checklist

- [Adjust the configuration settings](../../scripts/config/grype.yaml) to align with your project's specific requirements
- [Create a dependency baseline](https://github.com/anchore/grype#specifying-matches-to-ignore) for your repository excluding false-positives from the scanning process
- Make sure the GitHub action, which incorporates Syft and Grype, is part of your GitHub CI/CD workflow. More details on this can be found in the [NHSE Software Engineering Quality Framework](https://github.com/NHSDigital/software-engineering-quality-framework/blob/main/tools/dependency-scan/README.md)
- It is crucial to ensure that both, the SBOM and the vulnerabilities reports are uploaded to the central repository or a designated location for streamlined reporting and easy access. Here are the secret variables that has to be set for this functionality to work:
  - `IDP_AWS_REPORT_UPLOAD_ACCOUNT_ID` - the central AWS account ID where the reports will be uploaded; this will be set by a GitHub organization owner
  - `IDP_AWS_REPORT_UPLOAD_REGION` - the region of the AWS account; this will be set by a GitHub organization owner
  - `IDP_AWS_REPORT_UPLOAD_ROLE_NAME` - a dedicated role name for this repository that can authenticate to the central location for the purpose of uploading the reports
  - `IDP_AWS_REPORT_UPLOAD_BUCKET_ENDPOINT` - this is a dedicated S3 bucket endpoint for uploading the reports and should be in the following format `s3://bucket-name/repository-identifier`, without the trailing `/`
- If you have any queries about how to set this up, please contact either [@stefaniuk](https://github.com/stefaniuk) or [@andyblundell](https://github.com/andyblundell)

## Testing

You can run and test the process locally on a developer's workstation using the following commands

SBOM generator

```shell
./scripts/reports/create-sbom-report.sh
cat sbom-repository-report.json | jq
```

CVE scanner

```shell
./scripts/reports/scan-vulnerabilities.sh
cat vulnerabilities-repository-reportc.json | jq
```

## FAQ

1. _Why do we need to use all three tools: Syft, Grype, and Dependabot?_

   Syft, Grype, and Dependabot each serve unique functions in our CI/CD pipeline. Syft is used to generate a detailed Software Bill of Materials (SBOM), providing full visibility and traceability of all incorporated software components. Grype performs detailed scans of dependencies against the Common Vulnerabilities and Exposures (CVEs) list, adding an extra layer of security by introducing a quality gate in the delivery pipeline. Dependabot helps to keep your dependencies up-to-date and can also alert you to known vulnerabilities affecting your dependencies, showing the best path to resolution. By using all three, we ensure comprehensive dependency management is in place, from tracking and updating dependencies to identifying and rectifying found vulnerabilities.

2. _Why don't we use a GitHub Action already available on the Marketplace or the built-in security features of GitHub?_

   While we indeed leverage GitHub Actions within our CI/CD pipeline, they don't serve as a comprehensive solution for dependency management. Additionally, the built-in security features of GitHub aren't advanced enough to meet our specific requirements. Syft, Grype, and Dependabot provide specialised functionality that we integrate into our pipeline via GitHub Actions. By managing these tools as separate components, we gain greater flexibility in our configuration and can make finer adjustments as required, such as data enrichment.

3. _Is it feasible to consolidate this functionality into a custom GitHub Action?_

   Although consolidating this functionality into a custom GitHub Action seems like an optimal approach, this functionality also needs to run as a Git hook. Hence, shell scripting is a more suitable method as it makes less assumptions about local environment configuration or rely on third-party runners, providing quicker feedback. Additionally, incorporating this functionality directly into the repository has several advantages, including:

   - Improved transparency and visibility of the implementation
   - Easier investigation of CVEs found in the repository, eliminating dependence on a third party like GitHub
   - Enhanced portability and flexibility, allowing the scans to run in diverse environments

   However, this approach should be periodically reviewed as there is an emerging practice to use projects like [act](https://github.com/nektos/act) ~~to make GitHub Actions portable~~. Update: Please see the [Test GitHub Actions locally](../user-guides/Test_GitHub_Actions_locally.md) user guide.
