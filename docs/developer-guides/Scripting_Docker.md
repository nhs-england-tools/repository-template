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
    - [`Dockerignore` file](#dockerignore-file)
  - [FAQ](#faq)

## Overview

This document provides instructions on how to build Docker images using our automated build process. You'll learn how to specify version tags, commit changes, and understand the build output.

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

## Usage

### Quick start

The Repository Template assumes that you will want to build more than one docker image as part of your project.  As such, we do not use a `Dockerfile` at the root of the project.  Instead, each docker image that you create should go in its own folder under `infrastructure/images`.  So, if your application has a docker image called `my-shiny-app`, you should create the file `infrastructure/images/my-shiny-app/Dockerfile`.  Let's do that.

First, we need an application to package.  Let's do the simplest possible thing, and create a file called `main.py` in the root of the template with a familiar command in it:

```python
print("hello world")
```

Run this command to make the directory:

```shell
mkdir -p infrastructure/images/my-shiny-app
```

Now, edit `infrastructure/images/my-shiny-app/Dockerfile` and put this into it:

```dockerfile
FROM python

COPY ./main.py .

CMD ["python", "main.py"]
```

Note the paths in the `COPY` command.  The `Dockerfile` is stored in a subdirectory, but when `docker` runs it is executed in the root of the repository so that's where all paths are relative to.  This is because you can't `COPY` from parent directories. `COPY ../../main.py .` wouldn't work.

The name of the folder is also significant. It should match the name of the docker image that you want to create.  With that name, you can run the following `make` task to run `hadolint` over your `Dockerfile` to check for common anti-patterns:

```shell
 $ DOCKER_IMAGE=my-shiny-app make docker-lint
/workdir/./infrastructure/images/my-shiny-app/Dockerfile.effective:1 DL3006 warning: Always tag the version of an image explicitly
make[1]: *** [scripts/docker/docker.mk:34: _docker] Error 1
make: *** [scripts/docker/docker.mk:20: docker-lint] Error 2
```

All the provided docker `make` tasks take the `DOCKER_IMAGE` parameter.

`hadolint` found a problem, so let's fix that.  It's complaining that we've not specified which version of the `python` docker container we want. Change the first line of the `Dockerfile` to:

```dockerfile
FROM python:3.12-slim-bookworm
```

Run `DOCKER_IMAGE=my-shiny-app make docker-lint` again, and you will see that it is silent.

Now let's actually build the image.  Run the following:

```shell
DOCKER_IMAGE=my-shiny-app make docker-build
```

And now we can run it:

```shell
 $ DOCKER_IMAGE=my-shiny-app make docker-run
hello world
```

If you list your images, you'll see that the image name matches the directory name under `infrastructure/images`:

```shell
 $ docker image ls
REPOSITORY                   TAG                 IMAGE ID      CREATED        SIZE
localhost/my-shiny-app       latest              6a0adeb5348c  2 hours ago    135 MB
docker.io/library/python     3.12-slim-bookworm  d9f1825e4d49  5 weeks ago    135 MB
localhost/hadolint/hadolint  2.12.0-alpine       19b38dcec411  16 months ago  8.3 MB
```

Your process might want to add specific tag formats so you can identify docker images by date-stamps, or git hashes.  The Repository Template supports that with a `VERSION` file.  Create a new file called `infrastructure/images/my-shiny-app/VERSION`, and put the following into it:

```text
${yyyy}${mm}${dd}-${hash}
```

Now, run the `docker-build` command again, and towards the end of the output you will see something that looks like this:

```shell
Successfully tagged localhost/my-shiny-app:20240314-07ee679
```

Obviously the specific values will be different for you.  See the Versioning section below for more on this.

It is usually the case that there is a specific image that you will most often want to build, run, and deploy.  You should edit the root-level `Makefile` to document this and to provide shortcuts.  Edit `Makefile`, and change the `build` task to look like this:

```make
build: # Build the project artefact @Pipeline
	DOCKER_IMAGE=my-shiny-app
	make docker-build
```

Now when you run `make build`, it will do the right thing.  Keeping this convention consistent across projects means that new starters can be on-boarded quickly, without needing to learn a new set of conventions each time.

### Your image implementation

Always follow [Docker best practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/) while developing images.

Here is a step-by-step guide for an image which packages a third-party tool.  It is mostly similar to the example above, but demonstrates the `.tool-versions` mechanism.

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

### `Dockerignore` file

If you need to exclude files from a `COPY` command, put a [`Dockerfile.dockerignore`](https://docs.docker.com/build/building/context/#filename-and-location) file next to the relevant `Dockerfile`.  They do not live in the root directory.  Any paths within `Dockerfile.dockerignore` must be relative to the repository root.

## FAQ

1. _We built our serverless workloads based on AWS Lambda and package them as `.zip` archives. Why do we need Docker?_

   The primary use case for Docker and the thing it was invented for, is as a tool for aligning development environments. If you have no need for containers as a deployment artefact it is still worth using Docker as a development tool to ensure that everyone working on the project has the same versions of all dependencies, no matter what is installed on your individual machine.

2. _Should we use custom images for AWS Lambdas?_

   There should be few cases where this is necessary. Using the AWS-provided images should be the first preference, to minimise the amount of code and infrastructure effort we need to exert. However, there will be cases where the provided images do not work for you. If you think this applies - for instance, if you have inherited a deployable that requires an unsupported runtime - speak to Engineering so that we have awareness of the impact to you and your project and can try to help. See [Working with Lambda container images](https://docs.aws.amazon.com/lambda/latest/dg/images-create.html).
