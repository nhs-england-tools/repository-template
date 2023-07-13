# Guide: Scan dependencies

- [Guide: Scan dependencies](#guide-scan-dependencies)
  - [Overview](#overview)
  - [Key files](#key-files)
  - [Configuration checklist](#configuration-checklist)
  - [Testing](#testing)

## Overview

In modern software development, leveraging third-party dependencies is a common practice to reduce redundancy and improve efficiency. However, this introduces potential security risks and compliance issues into our codebase, making dependency scanning crucial. This process helps identify known vulnerabilities, or Common Vulnerabilities and Exposures (CVEs), in third-party libraries, allowing us to mitigate security threats proactively. Regular CVE scanning strengthens our codebase's security, ensuring adherence to top-tier security standards. In addition, generating a Software Bill of Materials (SBOM) - a comprehensive inventory of software components, libraries, and modules - is a valuable practice. SBOMs enhance transparency and traceability, giving an overview of all software elements, their versions, and associated licenses. This facilitates effective dependency management, compliance assurance, and timely response to version-specific vulnerabilities.

[Syfy](https://github.com/anchore/syft) and [Grype](https://github.com/anchore/grype) are valuable tools that can bolster this process. Syft generates a detailed SBOM, ensuring full visibility and traceability of all incorporated software components. This facilitates precise tracking, management, and potential updating of dependencies. On the other hand, Grype, as a vulnerability scanner, meticulously examines dependencies for known CVEs, providing an extra layer of security and allowing us to rectify vulnerabilities promptly. By incorporating Syft and Grype into our CI/CD pipeline, we can ensure continuous scanning of dependencies and generate an up-to-date SBOM. This approach enables real-time detection and resolution of vulnerabilities, thereby fortifying our software development lifecycle against security risks and ensuring adherence to compliance requirements.

## Key files

- [sbom-generator.sh](../../scripts/sbom-generator.sh): A shell script that generates SBOM (Software Bill of Materials)
- [.syft.yaml](../../scripts/config/.syft.yaml): A configuration file for the SBOM generator
- [cve-scanner.sh](../../scripts/cve-scanner.sh): A shell script that performs CVE analysis
- [.grype.yaml](../../scripts/config/.grype.yaml): A configuration file for the CVE scanner
- [scan-dependencies.yaml](../../.github/workflows/scan-dependencies.yaml): GitHub action to run the scripts as part of the CI/CD pipeline
- [.gitignore](../../.gitignore): Excludes the `sbom-spdx*.json` and `cve-scan*.json` report files created during the process

## Configuration checklist

- [Adjust the configuration settings](../../scripts/config/.grype.yaml) to align with your project's specific requirements
- [Create a dependency baseline](https://github.com/anchore/grype#specifying-matches-to-ignore) for your repository excluding false-positives from the scanning process
- Make sure the GitHub action, which incorporates Syft and Grype, is part of your GitHub CI/CD workflow. More details on this can be found in the [NHSE Software Engineering Quality Framework](https://github.com/NHSDigital/software-engineering-quality-framework/blob/main/tools/dependency-scan/README.md)
- It is crucial to ensure SBOM report is uploaded to a central repository or a designated location for streamlined reporting and easy access (TODO: Add more details here)

## Testing

You can run and test the process locally on a developer's workstation using the following commands

SBOM generator

```shell
./scripts/sbom-generator.sh
cat sbom-spdx.json | jq
```

CVE scanner

```shell
./scripts/cve-scanner.sh
cat cve-scan.json | jq
```
