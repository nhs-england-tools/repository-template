# Developer Guide: Scripting Docker

- [Developer Guide: Scripting Docker](#developer-guide-scripting-docker)
  - [Overview](#overview)
  - [Features](#features)
  - [Key files](#key-files)
  - [Usage](#usage)
    - [Quick start](#quick-start)
    - [Custom image implementation](#custom-image-implementation)
  - [Conventions](#conventions)
    - [Docker](#docker)
    - [Make](#make)
    - [Bash](#bash)
    - [Make and Bash working together](#make-and-bash-working-together)
  - [Resources](#resources)
  - [FAQ](#faq)

## Overview

Docker is a tool for developing, shipping, and running applications inside containers for Serverless and Kubernetes-based workloads. It has grown in popularity due to its ability to address several challenges faced by engineers, like:

- **Consistency across environments**: One of the common challenges in software development is the "it works on my machine" problem. Docker containers ensure that applications run the same regardless of where the container is run, be it a developer's local machine, a test environment, or a production server.
- **Isolation**: Docker containers are isolated from each other and from the host system. This means that you can run multiple versions of the same software (like databases or libraries) on the same machine without them interfering with each other.
- **Rapid development & deployment**: With Docker, setting up a new instance or environment is just a matter of spinning up a new container, which can be done in seconds. This is especially useful for scaling applications or rapidly deploying fixes.
- **Version control for environments**: Docker images can be versioned, allowing developers to keep track of application environments in the same way they version code. This makes it easy to roll back to a previous version if needed.
- **Resource efficiency**: Containers are lightweight compared to virtual machines (VMs) because they share the same OS kernel and do not require a full OS stack to run. This means you can run many more containers than VMs on a host machine.
- **Microservices architecture**: Docker is particularly well-suited for microservices architectures, where an application is split into smaller, independent services that run in their own containers. This allows for easier scaling, maintenance, and updates of individual services.
- **Integration with development tools**: There is a rich ecosystem of tools and platforms that integrate with Docker, including CI/CD tools (like GitHub and Azure DevOps), orchestration platforms (like Kubernetes), and cloud providers (like AWS and Azure).
- **Developer productivity**: With Docker, developers can easily share their environment with teammates. If a new developer joins the team, they can get up and running quickly by simply pulling the necessary Docker images.
- **Easy maintenance and update**: With containers, it is easy to update a base image or a software component and then propagate those changes to all instances of the application.
- **Cross-platform compatibility**: Docker containers can be run on any platform that supports Docker, be it Linux, Windows or macOS. This ensures compatibility across different development and production environments.
- **Security**: Docker provides features like secure namespaces and cgroups which isolate applications. Additionally, you can define fine-grained access controls and policies for your containers.
- **Reusable components**: Docker images can be used as base images for other projects, allowing for reusable components. For example, if you have a base image with a configured web server, other teams or projects can use that image as a starting point.

## Features

- Implementation of the most common Docker routines
- Use digest `sha256` for image versioning
- Pull image only once by its digest
- Store image versions in a single file, `.tool-versions`
- Build process optimisation for `amd64` architecture
- Image versioning automatically applied based on a pattern
- Dockerfile labels (metadata)
- Dockerfile linting
- Automated test suite for the Docker scripts
- Usage example

## Key files

- Scripts
  - [docker.lib.sh](../../scripts/docker/docker.lib.sh): A library code loaded by custom make targets and CLI scripts
  - [docker.mk](../../scripts/docker/docker.mk): Customised implementation of the Docker routines loaded by the `scripts/init.mk` file
  - [dgoss.sh](../../scripts/docker/dgoss.sh): Docker image spec test framework
  - [dockerfile-linter.sh](../../scripts/docker/dockerfile-linter.sh): Dockerfile linter
- Configuration
  - [.tool-versions](../../.tool-versions): Docker image versions
  - [hadolint.yaml](../../scripts/config/hadolint.yaml): Dockerfile linter configuration file
  - [Dockerfile.metadata](../../scripts/docker/Dockerfile.metadata)
- Test suite
  - [docker.test.sh](../../scripts/docker/tests/docker.test.sh)
  - [Dockerfile](../../scripts/docker/tests/Dockerfile)
  - [VERSION](../../scripts/docker/tests/VERSION)
- Usage example
  - [hello_world/requirements.txt](../../scripts/docker/examples/python/hello_world/requirements.txt)
  - [hello_world/app.py](../../scripts/docker/examples/python/hello_world/app.py)
  - [Dockerfile.effective](../../scripts/docker/examples/python/Dockerfile.effective)
  - [Dockerfile](../../scripts/docker/examples/python/Dockerfile)
  - [VERSION](../../scripts/docker/examples/python/VERSION)

## Usage

### Quick start

```shell
make docker-test-suite-run
```

```shell
make docker-example-build
make docker-example-run
```

### Custom image implementation

- Create custom image definition
- Build image
- Integrate with the CD pipeline

## Conventions

### Docker

`--platform linux/amd64` image

Usage of `Dockerfile`, `Dockerfile.metadata` and `Dockerfile.effective`

Usage of `VERSION` and `.version` files

- Multiple entries in `VERSION`

Image versions

```text
# docker/image/name 1.0.0@sha256:1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
```

### Make

```makefile
some-target: # Short target description - mandatory: foo=[description]; optional: baz=[description, default is 'qux']
    # Recipe implementation...
```

```shell
foo=bar make some-target # Environment variable is passed to the make target execution
make some-target foo=bar # Make argument is passed to the make target execution
```

By convention we use upper-case variables for global settings that you would ordinarily associate with environment variables. We use lower-case variables as arguments to specific functions (or targets, in this case).

`.SILENT` section of `make` file

### Bash

```shell
# Short function description
# Arguments (provided as environment variables):
#   foo=[description]
#   baz=[description, default is 'qux']
function some-shell-function() {
    # Function implementation...
```

```shell
source ./scripts/a-suite-of-shell-functions
foo=bar some-shell-function # Environment variable is passed to the function
```

```shell
source ./scripts/a-suite-of-shell-functions
foo=bar
some-shell-function # Environment variable is still passed to the function
```

```shell
# Environment variable has to be exported to be passed to a child process, DO NOT use this pattern
export foo=bar
./scripts/a-shell-script
```

```shell
# or to be set in the same line before creating a new process, prefer this pattern over the previous one
foo=bar ./scripts/a-shell-script
```

By convention we use upper-case variables for global settings that you would ordinarily associate with environment variables. We use lower-case variables as arguments to specific functions (or targets, in this case).

`set -euo pipefail` in Bash script

`local` variables in Bash script

### Make and Bash working together

```makefile
some-target: # Run shell function - mandatory: foo=[description]
    source ./scripts/a-suite-of-shell-function
    some-shell-function # 'foo' is passed to the function by 'make'
```

```shell
foo=bar make some-target
```

## Resources

- GNU utils repository

## FAQ

1. _We built our serverless workloads based on AWS Lambda and package them as `.zip` archives. Why do we need Docker?_

   The primary use case for Docker and the thing it was invented for, is as a tool for aligning development environments. If you have no need for containers as a deployment artefact it is still worth using Docker as a development tool to ensure that everyone working on the project has the same versions of all dependencies, no matter what is installed on your individual machine.

2. _Should we use custom images for AWS Lambdas?_

   There should be few cases where this is necessary. Using the AWS-provided images should be the first preference, to minimise the amount of code and infrastructure effort we need to exert. However, there will be cases where the provided images do not work for you. If you think this applies - for instance, if you have inherited a deployable that requires an unsupported runtime - speak to Engineering so that we have awareness of the impact to you and your project and can try to help. See [Working with Lambda container images](https://docs.aws.amazon.com/lambda/latest/dg/images-create.html).
