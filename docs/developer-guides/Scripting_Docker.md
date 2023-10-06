# Developer Guide: Scripting Docker

- [Developer Guide: Scripting Docker](#developer-guide-scripting-docker)
  - [Overview](#overview)
  - [Features](#features)
  - [Key files](#key-files)
  - [Usage](#usage)
    - [Quick start](#quick-start)
    - [Your image implementation](#your-image-implementation)
  - [Conventions](#conventions)
    - [Versioning](#versioning)
    - [Variables](#variables)
    - [Platform architecture](#platform-architecture)
  - [FAQ](#faq)

## Overview

Docker is a tool for developing, shipping and running applications inside containers for Serverless and Kubernetes-based workloads. It has grown in popularity due to its ability to address several challenges faced by engineers, like:

- **Consistency across environments**: One of the common challenges in software development is the "it works on my machine" problem. Docker containers ensure that applications run the same regardless of where the container is run, be it a developer's local machine, a test environment or a production server.
- **Isolation**: Docker containers are isolated from each other and from the host system. This means that you can run multiple versions of the same software (like databases or libraries) on the same machine without them interfering with each other.
- **Rapid development and deployment**: With Docker, setting up a new instance or environment is just a matter of spinning up a new container, which can be done in seconds. This is especially useful for scaling applications or rapidly deploying fixes.
- **Version control for environments**: Docker images can be versioned, allowing developers to keep track of application environments in the same way they version code. This makes it easy to roll back to a previous version if needed.
- **Resource efficiency**: Containers are lightweight compared to virtual machines (VMs) because they share the same OS kernel and do not require a full OS stack to run. This means you can run many more containers than VMs on a host machine.
- **Microservices architecture**: Docker is particularly well-suited for microservices architectures, where an application is split into smaller, independent services that run in their own containers. This allows for easier scaling, maintenance and updates of individual services.
- **Integration with development tools**: There is a rich ecosystem of tools and platforms that integrate with Docker, including CI/CD tools (like GitHub and Azure DevOps), orchestration platforms (like Kubernetes) and cloud providers (like AWS and Azure).
- **Developer productivity**: With Docker, developers can easily share their environment with teammates. If a new developer joins the team, they can get up and running quickly by simply pulling the necessary Docker images.
- **Easy maintenance and update**: With containers, it is easy to update a base image or a software component and then propagate those changes to all instances of the application.
- **Cross-platform compatibility**: Docker containers can be run on any platform that supports Docker, be it Linux, Windows or macOS. This ensures compatibility across different development and production environments.
- **Security**: Docker provides features like secure namespaces and cgroups which isolate applications. Additionally, you can define fine-grained access controls and policies for your containers.
- **Reusable components**: Docker images can be used as base images for other projects, allowing for reusable components. For example, if you have a base image with a configured web server, other teams or projects can use that image as a starting point.

## Features

Here are some key features built into this repository's Docker module:

- Implements the most common Docker routines for efficient container management, e.g. build, test and push
- Utilises `sha256` digests for robust image versioning and to enhance security posture
- Enables pull-image-once retrieval based on its digest to optimise performance (Docker does not store `sha256` digests locally)
- Consolidates image versions in a unified `.tool-versions` file for easier dependency management
- Optimises the build process specifically for the `amd64` architecture for consistency
- Applies automatic image versioning according to a predefined pattern for artefact publishing and deployment
- Incorporates metadata through `Dockerfile` labels for enhanced documentation and to conform to standards
- Integrates a linting routine to ensure `Dockerfile` code quality
- Includes an automated test suite to validate Docker scripts
- Provides a ready-to-run example to demonstrate the module's functionality
- Incorporates a best practice guide

## Key files

- Scripts
  - [`docker.lib.sh`](../../scripts/docker/docker.lib.sh): A library code loaded by custom make targets and CLI scripts
  - [`docker.mk`](../../scripts/docker/docker.mk): Customised implementation of the Docker routines loaded by the `scripts/init.mk` file
  - [`dgoss.sh`](../../scripts/docker/dgoss.sh): Docker image spec test framework
  - [`dockerfile-linter.sh`](../../scripts/docker/dockerfile-linter.sh): `Dockerfile` linter
- Configuration
  - [`.tool-versions`](../../.tool-versions): Stores Docker image versions
  - [`hadolint.yaml`](../../scripts/config/hadolint.yaml): `Dockerfile` linter configuration file
  - [`Dockerfile.metadata`](../../scripts/docker/Dockerfile.metadata): Labels added to image definition as specified by the spec
- Test suite
  - [`docker.test.sh`](../../scripts/docker/tests/docker.test.sh): Main file containing all the tests
  - [`Dockerfile`](../../scripts/docker/tests/Dockerfile): Image definition for the test suite
  - [`VERSION`](../../scripts/docker/tests/VERSION): Version patterns for the test suite
- Usage example
  - Python-based example [`hello_world`](../../scripts/docker/examples/python) app showing a multi-staged build
  - A set of [make targets](https://github.com/nhs-england-tools/repository-template/blob/main/scripts/docker/docker.mk#L18) to run the example

## Usage

### Quick start

Run the test suite:

```shell
$ make docker-test-suite-run

test-docker-build PASS
test-docker-test PASS
test-docker-run PASS
test-docker-clean PASS
```

Run the example:

```shell
$ make docker-example-build

#0 building with "desktop-linux" instance using docker driver
...
#12 DONE 0.0s

$ make docker-example-run

 * Serving Flask app 'app'
 * Debug mode: off
WARNING: This is a development server. Do not use it in a production deployment. Use a production WSGI server instead.
 * Running on all addresses (0.0.0.0)
 * Running on http://127.0.0.1:8000
 * Running on http://172.17.0.2:8000
Press CTRL+C to quit
```

### Your image implementation

Always follow [Docker best practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/) while developing images. Start with creating your container definition for the service and store it in the `infrastructure/images` directory.

Here is a step-by-step guide:

1. Create `infrastructure/images/cypress/Dockerfile`

   ```Dockerfile
   # hadolint ignore=DL3007
   FROM cypress/browsers:latest
   ```

2. Add the following entry to the `.tool-versions` file. This will be used to replace the `latest` version placeholder in the `Dockerfile`.

   ```text
   # docker/cypress/browsers node-20.5.0-chrome-114.0.5735.133-1-ff-114.0.2-edge-114.0.1823.51-1@sha256:8b899d0292e700c80629d13a98ae309295e719f5b4f9aa50a98c6cdd2b6c5215
   ```

3. Create `infrastructure/images/cypress/VERSION`

   ```text
   ${yyyy}${mm}${dd}-${hash}
   ```

4. Add make target to the `Makefile`

   ```text
   build-cypress-image: # Build Cypress Docker image
     docker_image=ghcr.io/nhs-england-tools/cypress \
     docker_title="Browser testing" \
       make docker-build dir=infrastructure/images/cypress

   ${VERBOSE}.SILENT: \
     build-cypress-image \
   ```

5. Run the build

   ```text
   $ make build-cypress-image
   #0 building with "desktop-linux" instance using docker driver
   ...
   #5 exporting to image
   #5 exporting layers done
   #5 writing image sha256:7440a1a25110cf51f9a1c8a2e0b446e9770ac0db027e55a7d31f2e217f2ff0c7 done
   #5 naming to ghcr.io/nhs-england-tools/cypress:20230828-eade960 done
   #5 DONE 0.0s

   $ docker images
   REPOSITORY                          TAG                IMAGE ID       CREATED       SIZE
   ghcr.io/nhs-england-tools/cypress   20230828-eade960   7440a1a25110   2 weeks ago   608MB
   ghcr.io/nhs-england-tools/cypress   latest             7440a1a25110   2 weeks ago   608MB
   ```

6. Commit all changes to these files

- `infrastructure/images/cypress/Dockerfile`
- `infrastructure/images/cypress/Dockerfile.effective`
- `infrastructure/images/cypress/VERSION`
- `.tool-versions`

## Conventions

### Versioning

You can specify the version tags that the automated build process applies to your images with a `VERSION` file. This file must be located adjacent to the `Dockerfile` where each image is defined.

It may be a "_statically defined_" version, such as `1.2.3`, `20230601`, etc., or a "_dynamic pattern_" based on the current time and commit hash, e.g. `${yyyy}${mm}${dd}${HH}${MM}${SS}-${hash}`. This pattern will be substituted during the build process to create a `.version` file in the same directory, containing effective content like `20230601153000-123abcd`. See [this function](https://github.com/nhs-england-tools/repository-template/blob/main/scripts/docker/docker.lib.sh#L118) for what template substitutions are available.

This file is then used by functions defined in [docker.lib.sh](../../scripts/docker/docker.lib.sh) but is ignored by Git, and is not checked in with other files.

Support for multiple version entries is provided. For instance, if the `VERSION` file contains:

```text
${yyyy}${mm}${dd}
${yyyy}${mm}${dd}${HH}${MM}
${yyyy}${mm}${dd}-${hash}
squirrel
```

The corresponding `.version` file generated by the `docker-build` function may appear as:

```text
20230601
20230601-123abcd
squirrel
```

In this case, the image is automatically tagged as `20230601`, `20230601-123abcd`, `squirrel` and `latest`, which can be then pushed to a registry by running the `docker-push` function. This versioning approach is particularly useful for projects with multiple deployments per day.

> [!NOTE]<br>
> The preferred pattern for versioning is `${yyyy}${mm}${dd}${HH}${MM}` or/and `${yyyy}${mm}${dd}-${hash}` for projects with a cadence of multiple deployments per day. This is compatible with the [Calendar Versioning / CalVer](https://calver.org/) convention.

Base image versions are maintained in the [.tool-versions](../../.tool-versions) file located in the project's top-level directory. The format is as follows:

```text
# docker/image/name 1.0.0@sha256:1234567890...abcdef
```

This method facilitates dependency management through a single file. The `docker-build` function will replace any instance of `FROM image/name:latest` with `FROM image/name:1.0.0@sha256:1234567890...abcdef`. Additionally, the [Dockerfile.metadata](../../scripts/docker/Dockerfile.metadata) file will be appended to the end of the `Dockerfile.effective` created by the process.

The reason we do this is so that the deployment version is source-controlled, but the tooling does not interfere with using a more recent Docker image during local development before the new version can be added to the `.tool-versions` file. It also serves as a clean way of templating Docker image definition.

### Variables

Set the `docker_image` or `DOCKER_IMAGE` variable for your image. Alternatively, you can use their shorthand versions, `image` or `IMAGE`. To emphasize that it is a global variable, using the uppercase version is recommended, depending on your implementation.

### Platform architecture

For cross-platform image support, the `--platform linux/amd64` flag is used to build Docker images, enabling containers to run without any changes on both `amd64` and `arm64` architectures (via emulation).

## FAQ

1. _We built our serverless workloads based on AWS Lambda and package them as `.zip` archives. Why do we need Docker?_

   The primary use case for Docker and the thing it was invented for, is as a tool for aligning development environments. If you have no need for containers as a deployment artefact it is still worth using Docker as a development tool to ensure that everyone working on the project has the same versions of all dependencies, no matter what is installed on your individual machine.

2. _Should we use custom images for AWS Lambdas?_

   There should be few cases where this is necessary. Using the AWS-provided images should be the first preference, to minimise the amount of code and infrastructure effort we need to exert. However, there will be cases where the provided images do not work for you. If you think this applies - for instance, if you have inherited a deployable that requires an unsupported runtime - speak to Engineering so that we have awareness of the impact to you and your project and can try to help. See [Working with Lambda container images](https://docs.aws.amazon.com/lambda/latest/dg/images-create.html).
