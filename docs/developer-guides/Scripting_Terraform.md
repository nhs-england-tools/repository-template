# Developer Guide: Scripting Terraform

- [Developer Guide: Scripting Terraform](#developer-guide-scripting-terraform)
  - [Overview](#overview)
  - [Features](#features)
  - [Key files](#key-files)
  - [Usage](#usage)
    - [Quick start](#quick-start)
    - [Your stack implementation](#your-stack-implementation)
  - [Conventions](#conventions)
    - [Secrets](#secrets)
    - [Variables](#variables)
    - [IaC directory](#iac-directory)
  - [FAQ](#faq)

## Overview

Terraform is an open-source infrastructure as code (IaC) tool. It allows you to define, provision and manage infrastructure in a declarative way, using a configuration language called HCL. Terraform can manage a wide variety of resources, such as virtual machines, databases, networking components and many more, across multiple cloud providers like AWS and Azure.

Some advantages of using Terraform are as outlined below:

- **Declarative configuration**: Terraform enables the precise definition of the desired state of infrastructure, streamlining its creation through a readable and understandable codebase.
- **Version control**: The infrastructure code may be subject to version control, thereby providing an audit trail of environmental changes.
- **Modularisation and reusability**: Terraform facilitates the packaging of infrastructure into modular components, enhancing both reusability and ease of sharing across organisational teams.
- **State management**: Terraform's state management capabilities ensure an accurate representation of real-world resources, enabling features such as resource dependencies and idempotence.
- **Collaboration and workflow**: The platform supports collaboration through features like remote backends and state locking, thereby fostering collective work on infrastructure projects.
- **Community and ecosystem**: A robust community actively contributes to the Terraform ecosystem, providing a wealth of modules and examples that expedite infrastructure development.

## Features

Here are some key features built into this repository's Terraform module:

- Provides Make targets for frequently-used Terraform commands for streamlined execution
- Offers code completion and command signature assistance via Make for enhanced CLI usability
- Supports named arguments with default values for an improved coding experience
- Allows the working directory to be controlled by either arguments or a predefined constant for flexible stack management
- Features a command wrapper to improve the onboarding experience and ensure environmental consistency
- Incorporates both a Git hook and a GitHub action to enforce code quality standards
- Comes with the CI/CD pipeline workflow integration
- Includes a file cleanup routine to efficiently remove temporary resources
- Incorporates a ready-to-run example to demonstrate the module's capabilities
- Integrates a code linting routine to ensure scripts are free from unintended side effects
- Includes a verbose mode for in-depth troubleshooting and debugging
- Incorporates a best practice guide

## Key files

- Scripts
  - [`terraform.lib.sh`](../../scripts/terraform/terraform.lib.sh) A library code loaded by custom make targets and CLI scripts
  - [`terraform.mk`](../../scripts/terraform/terraform.mk): Customised implementation of the Terraform routines loaded by the `scripts/init.mk` file
  - [`terraform.sh`](../../scripts/terraform/terraform.sh): Terraform command wrapper
- Configuration
  - [`.tool-versions`](../../.tool-versions): Stores Terraform version to be used
- Code quality gates
  - [`lint-terraform/action.yaml`](../../.github/actions/lint-terraform/action.yaml): GitHub action
  - [`check-terraform-format.sh`](../../scripts/githooks/check-terraform-format.sh): Git hook
- Usage example
  - Declarative infrastructure definition example [`terraform-state-aws-s3`](../../scripts/terraform/examples/terraform-state-aws-s3) to store Terraform state
  - A set of [make targets](https://github.com/nhs-england-tools/repository-template/blob/main/scripts/terraform/terraform.mk#L44) to run the example

## Usage

### Quick start

Run the example:

```shell
# AWS console access setup
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."
```

```shell
$ make terraform-example-provision-aws-infrastructure

Initializing the backend..
...
Plan: 5 to add, 0 to change, 0 to destroy.
Saved the plan to: terraform.tfplan
To perform exactly these actions, run the following command to apply:
    terraform apply "terraform.tfplan"
...
Apply complete! Resources: 5 added, 0 changed, 0 destroyed.

$ make terraform-example-destroy-aws-infrastructure

...
Plan: 0 to add, 0 to change, 5 to destroy.
...
Apply complete! Resources: 0 added, 0 changed, 5 destroyed.
```

### Your stack implementation

Always follow [best practices for using Terraform](https://cloud.google.com/docs/terraform/best-practices-for-terraform) while providing infrastructure as code (IaC) for your service.

Directory structure:

```shell
service-repository/
├─ ...
└─ infrastructure/
   ├─ modules/
   │  ├─ service-module-name/
   │  │  ├─ main.tf
   │  │  ├─ outputs.tf
   │  │  ├─ variables.tf
   │  │  ├─ versions.tf
   │  │  └─ README.md
   │  ...
   ├─ environments/
   │  ├─ dev/ # This is where your ephemeral environments live
   │  │  ├─ backend.tf
   │  │  ├─ main.tf
   │  │  ├─ provider.tf
   │  │  └─ terraform.tfvars
   │  ├─ nonprod/
   |  │  ├─ ...
   │  └─ prod/
   |     ├─ ...
   └─ .gitignore
```

At its core, the structure of the Terraform setup consists of two main parts. The `modules` section is designed to house the shared or common configurations for a service. Meanwhile, the individual folders for each environment, like `dev` (ephemeral environments), `nonprod`, `prod` and so on, invoke these shared modules while also defining their unique variables and parameters. By arranging resources in distinct Terraform directories for every component, we ensure clarity and promote cohesion. Each environment directory not only references shared code from the `modules` section but also represents a default Terraform workspace as a deployment of the service to the designated environment.

Stack management:

```shell
export STACK=infrastructure/environments/dev # or use 'dir' argument on each command
make terraform-init
make terraform-plan opts="-out=terraform.tfplan"
make terraform-apply opts="-auto-approve terraform.tfplan"
make terraform-destroy opts="-auto-approve"
```

Plugging it in to the CI/CD pipeline lifecycle:

```shell
deploy: # Deploy the project artefact to the target environment
  # The value assigned to this variable should be driven by the GitHub environments setup
  STACK=infrastructure/environments/security-test \
    make environment-set-up
  # Prepare datastore
  # Deploy artefact

environment-set-up: # Use for all environment types - STACK=[path to your stack]
  make terraform-init
  make terraform-plan opts="-out=terraform.tfplan"
  make terraform-apply opts="-auto-approve terraform.tfplan"

environment-tear-down: # Use only for ephemeral environments, e.g. dev and test automation - STACK=[path to your stack]
  make terraform-destroy opts="-auto-approve"
```

## Conventions

### Secrets

GitHub secrets for Terraform must be granular to avoid appearing in logs. For example, use `arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/${{ secrets.AWS_ASSUME_ROLE_NAME }}`. It has been proven that if a role ARN is defined as `AWS_ROLE_ARN`, details such as the account number are not redacted from the output and are visible in plain text. While this information may not be considered sensitive on its own, it could contribute to a vector attack and therefore be used to exploit the service.

### Variables

To specify the location of your Terraform [root module](https://developer.hashicorp.com/terraform/language/modules#the-root-module) set the `terraform_stack` or `TERRAFORM_STACK` variable. Alternatively, you can use their shorthand versions, `stack` or `STACK`. To emphasize that it is a global variable, using the uppercase version is recommended, depending on your implementation. All environment stacks must be root modules and should be located in the `infrastructure/environments` directory.

### IaC directory

The `infrastructure` directory is used to store IaC, as it is the most descriptive and portable name. This approach enables the use of supporting technologies, CDKs and solutions specific to the cloud providers like AWS and Azure.

## FAQ

1. _What are the advantages of using this module over directly invoking Terraform commands?_

   The primary purpose of this module is to integrate best practices for CI/CD pipeline workflows with infrastructure as code (IaC), offering a well-defined structural framework that encourages modularisation and reusability of components. Additionally, it enhances the onboarding experience and increases the portability of the provisioning process.
