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

The Repository Template assumes that you will be constructing the bulk of your infrastructure in `infrastructure/modules` as generic deployment configuration, which you will then compose into environment-specific modules, each stored in their own directory under `infrastructure/environments`.  Let's create a simple deployable thing, and configure an S3 bucket.  We'll make the name of the bucket a variable, so that each environment can have its own.

Open the file `infrastructure/modules/private_s3_bucket/main.tf`, and put this in it:

```terraform
# Define the provider
provider "aws" {
  region = "eu-west-2"
}

variable "bucket_name" {
  description = "Name of the bucket, which can be different per environment"
}

resource "aws_s3_bucket" "my_bucket" {
  bucket = var.bucket_name # Replace with your desired bucket name
  acl    = "private"
}
```

Note that the variable has been given no value.  This is intentional, and allows us to pass the bucket name in as a parameter from the environment.

Now, we're going to define two deployment environments: `dev`, and `test`.  Run this:

```bash
mkdir -p infrastructure/environments/{dev,test}
```

It is important that the directory names match your environment names.

Now, let's create the environment definition files.  Open `infrastructure/environments/dev/main.tf` and copy in:

```terraform
module "dev_environment" {
  source = "../../modules/private_s3_bucket"
  bucket_name = "nhse-ee-my-fancy-bucket"
}
```

Some things to note:

- The `source` path is relative to the directory that the `main.tf` file is in.  When `terraform` runs, it will `chdir` to that directory first, before doing anything else.
- The `module` name, `"dev_environment"` here, can be anything.  Module names are only scoped to the file they're in, so you don't need to follow any particular convention here.
- The `bucket_name` is going to end up as the bucket name in AWS.  It wants to be meaningful to you, and you need to pick your own.  The framework doesn't constrain your choice, but remember that AWS needs them to be globally unique and if you steal `"nhse-ee-my-fancy-bucket"` then I can't test these docs and then I will be sad.

Let's create our `test` environment now.  Open `infrastructure/environments/test/main.tf` and copy in:

```terraform
module "test_environment" {
  source = "../../modules/private_s3_bucket"
  bucket_name = "nhse-ee-my-fancy-test-bucket"
}
```

We have changed the bucket name here.  In this example, I am making no assumptions as to how your AWS accounts are set up.  If you intend for your development and test infrastructure to be in the same AWS account (perhaps by necessity, for organisational reasons) and you need to separate them by a naming convention, the framework can support that.

Now we have our modules and our environments configured, we need to initialise each of them.  Run these two commands:

```bash
TF_ENV=dev make terraform-init
TF_ENV=test make terraform-init
```

Each invocation will download the `terraform` dependencies we need.  The `TF_ENV` name we give to each invocation is the name of the environment, and must match the directory name we chose under `infrastructure/environments` so that `make` gives the right parameters to `terraform`.

We are now ready to try deploying to AWS, from our local environment.

I am going to assume that you have an `~/.aws/credentials` file set up with a separate profile for each environment that you want to use, called `my-test-environment` and `my-dev-environment`.  They might have the same credential values in them, in which case `terraform` will create the resources in the same account; or you might have them set up to deploy to different accounts.  Either would work.

Run the following:

```shell
TF_ENV=dev AWS_PROFILE=my-dev-environment make terraform-plan
```

If all is working correctly (and you may need to do a round of `aws sso login` first), you should see this output:

```text

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # module.dev_environment.aws_s3_bucket.my_bucket will be created
  + resource "aws_s3_bucket" "my_bucket" {
      + acceleration_status         = (known after apply)
      + acl                         = "private"
      + arn                         = (known after apply)
      + bucket                      = "my-dev-bucket"
      + bucket_domain_name          = (known after apply)
      + bucket_prefix               = (known after apply)
      + bucket_regional_domain_name = (known after apply)
      + force_destroy               = false
      + hosted_zone_id              = (known after apply)
      + id                          = (known after apply)
      + object_lock_enabled         = (known after apply)
      + policy                      = (known after apply)
      + region                      = (known after apply)
      + request_payer               = (known after apply)
      + tags_all                    = (known after apply)
      + website_domain              = (known after apply)
      + website_endpoint            = (known after apply)
    }

Plan: 1 to add, 0 to change, 0 to destroy.

─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

Note: You didn't use the -out option to save this plan, so Terraform can't guarantee to take exactly these actions if you run "terraform apply" now.

```

No errors found, so we can now create the bucket:

```shell
 $ TF_ENV=dev AWS_PROFILE=my-dev-environment make terraform-apply

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # module.dev_environment.aws_s3_bucket.my_bucket will be created
  + resource "aws_s3_bucket" "my_bucket" {
      + acceleration_status         = (known after apply)
      + acl                         = (known after apply)
      + arn                         = (known after apply)
      + bucket                      = "nhse-ee-my-dev-bucket"
      + bucket_domain_name          = (known after apply)
      + bucket_prefix               = (known after apply)
      + bucket_regional_domain_name = (known after apply)
      + force_destroy               = false
      + hosted_zone_id              = (known after apply)
      + id                          = (known after apply)
      + object_lock_enabled         = (known after apply)
      + policy                      = (known after apply)
      + region                      = (known after apply)
      + request_payer               = (known after apply)
      + tags_all                    = (known after apply)
      + website_domain              = (known after apply)
      + website_endpoint            = (known after apply)
    }

Plan: 1 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

module.dev_environment.aws_s3_bucket.my_bucket: Creating...
module.dev_environment.aws_s3_bucket.my_bucket: Creation complete after 1s [id=nhse-ee-my-dev-bucket]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

```

You will notice here that I needed to confirm the action to `terraform` manually.  If you don't want to do that, you can pass the `-auto-approve` option to `terraform` like this:

```shell
TF_ENV=dev AWS_PROFILE=my-dev-environment make terraform-apply opts="-auto-approve"
```

If you check the contents of your AWS account, you should see your new bucket:

```shell
 $ aws s3 ls --profile my-dev-environment
...
2024-03-01 16:33:55 nhse-ee-my-dev-bucket
```

Now I don't want to leave that there, so I will run the corresponding `destroy` command to get rid of it:

```shell
 $ TF_ENV=dev AWS_PROFILE=my-dev-environment make terraform-destroy opts="-auto-approve"
module.dev_environment.aws_s3_bucket.my_bucket: Refreshing state... [id=nhse-ee-my-dev-bucket]

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  - destroy

Terraform will perform the following actions:

  # module.dev_environment.aws_s3_bucket.my_bucket will be destroyed
  ...(more terraform output not shown because it's boring, but the end result is the bucket going away)
```

To create your `test` environment, you run the same commands with `test` where previously you had `dev`:

```shell
TF_ENV=test AWS_PROFILE=my-test-environment make terraform-apply opts="-auto-approve"
```

To use the same `terraform` files in a GitHub action, see the docs [here](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services).

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
