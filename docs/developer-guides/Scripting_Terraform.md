# Developer Guide: Scripting Terraform

- [Developer Guide: Scripting Terraform](#developer-guide-scripting-terraform)
  - [Overview](#overview)
  - [Features](#features)
  - [Key files](#key-files)
  - [Usage](#usage)
    - [Quick start](#quick-start)
  - [Conventions](#conventions)
  - [FAQ](#faq)

## Overview

- Explain why Terraform
- Mention CDK for Terraform

## Features

- Make targets

## Key files

- Scripts
  - [terraform.lib.sh](scripts/terraform/terraform.lib.sh)

## Usage

- The `./infrastructure` directory
- Breaking down IaC into modules and stacks
- Usage of the Terraform make targets in the `./Makefile`
- GitHub secrets for Terraform must be granular to not appear in the logs, i.e. `arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/${{ secrets.AWS_ASSUME_ROLE_NAME }}`

### Quick start

```shell
# AWS console access setup
make terraform-example-provision-infrastructure
make terraform-example-destroy-infrastructure
```

## Conventions

## FAQ
