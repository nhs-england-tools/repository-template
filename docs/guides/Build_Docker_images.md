# Build Docker images

- [Build Docker images](#build-docker-images)
  - [Overview](#overview)
  - [Key files](#key-files)
  - [Usage](#usage)
    - [Quick start](#quick-start)
    - [Build with a pinned base image](#build-with-a-pinned-base-image)
    - [Pin a new base image](#pin-a-new-base-image)
    - [Testing your image](#testing-your-image)
  - [Conventions](#conventions)
    - [Versioning](#versioning)
    - [Variables](#variables)
    - [Platform architecture](#platform-architecture)
    - [`Dockerignore` file](#dockerignore-file)

## Overview

The [Docker Make targets](../../scripts/docker/docker.mk) build, lint, run and
push images from a project Dockerfile. The functions in
[docker.lib.sh](../../scripts/docker/docker.lib.sh) bake a
`Dockerfile.effective`, apply metadata and tag images using an optional
`VERSION` file. The [quick-start prerequisites](../../README.md#prerequisites)
include GNU tools and a container runtime. Review and trust `mise.toml`, then
run `make config` to install the pinned tools before building an image.

## Key files

- Scripts
  - [`docker.lib.sh`](../../scripts/docker/docker.lib.sh): A library code loaded
    by custom make targets and CLI scripts
  - [`docker.mk`](../../scripts/docker/docker.mk): Customised implementation of
    the Docker routines loaded by the `scripts/init.mk` file
  - [`dockerfile-linter.sh`](../../scripts/docker/dockerfile-linter.sh):
    `Dockerfile` linter
- Configuration
  - [`mise.toml`](../../mise.toml): Stores toolchain pins and, in its
    `[_.docker]` table, Docker image versions
  - [`hadolint.yaml`](../../scripts/config/hadolint.yaml): `Dockerfile` linter
    configuration file
  - [`Dockerfile.metadata`](../../scripts/docker/Dockerfile.metadata): Labels
    added to image definition as specified by the spec
- Test suite
  - [`docker.test.sh`](../../scripts/docker/tests/docker.test.sh): Main file
    containing all the tests
  - [`Dockerfile`](../../scripts/docker/tests/Dockerfile): Image definition for
    the test suite
  - [`VERSION`](../../scripts/docker/tests/VERSION): Version patterns for the
    test suite

## Usage

### Quick start

By default, the Make targets look for an image's `Dockerfile` under
`infrastructure/images/$DOCKER_IMAGE`. You can supply `dir=<path>` to use a
different location. This example creates an image named `my-shiny-app` under
the default directory. Its application and Dockerfile are not bundled with the
template.

First, we need an application to package. Let's do the simplest possible thing,
and create a file called `main.py` in the root of the template with a familiar
command in it:

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

Note the paths in the `COPY` command. The `Dockerfile` is stored in a
subdirectory, but when `docker` runs it is executed in the root of the
repository so that's where all paths are relative to. This is because you can't
`COPY` from parent directories. `COPY ../../main.py .` wouldn't work.

The name of the folder is also significant. It should match the name of the
docker image that you want to create. With that name, you can run the following
`make` task to run `hadolint` over your `Dockerfile` to check for common
anti-patterns:

```shell
 $ DOCKER_IMAGE=my-shiny-app make docker-lint
/workdir/./infrastructure/images/my-shiny-app/Dockerfile.effective:1 DL3006 warning: Always tag the version of an image explicitly
make[1]: *** [scripts/docker/docker.mk:34: _docker] Error 1
make: *** [scripts/docker/docker.mk:20: docker-lint] Error 2
```

All the provided docker `make` tasks take the `DOCKER_IMAGE` parameter.

`hadolint` found a problem, so let's fix that. It's complaining that we've not
specified which version of the `python` docker container we want. Change the
first line of the `Dockerfile` to:

```dockerfile
FROM python:3.12-slim-bookworm
```

Run `DOCKER_IMAGE=my-shiny-app make docker-lint` again, and you will see that it
is silent.

Now let's actually build the image. Run the following:

```shell
DOCKER_IMAGE=my-shiny-app make docker-build
```

And now we can run it:

```shell
 $ DOCKER_IMAGE=my-shiny-app make docker-run
hello world
```

Confirm that the image has been built:

```shell
docker image ls my-shiny-app
```

Your process might want to add specific tag formats so you can identify docker
images by date-stamps, or git hashes. The Repository Template supports that with
a `VERSION` file. Create a new file called
`infrastructure/images/my-shiny-app/VERSION`, and put the following into it:

```text
${yyyy}${mm}${dd}-${hash}
```

Run `DOCKER_IMAGE=my-shiny-app make docker-build` again. The helper tags the
image as `my-shiny-app:<date>-<hash>` and `my-shiny-app:latest`. See the
Versioning section below for more on this.

It is usually the case that there is a specific image that you will most often
want to build, run, and deploy. You should edit the root-level `Makefile` to
document this and to provide shortcuts. Edit `Makefile`, and change the `build`
target to look like this. Replace the leading spaces in the recipe with a
literal tab when adding it to the Makefile:

```makefile
build: # Build the project artefact @Build
  $(MAKE) docker-build DOCKER_IMAGE=my-shiny-app
```

Now when you run `make build`, it will do the right thing. Keeping this
convention consistent across projects means that new starters can be on-boarded
quickly, without needing to learn a new set of conventions each time.

### Build with a pinned base image

The template pins the `node` image in [mise.toml](../../mise.toml). To use that
pin in a new image:

Create `infrastructure/images/node-tool/Dockerfile`:

```dockerfile
ARG NODE_VERSION=26.12.0-slim
FROM node:${NODE_VERSION}
CMD ["node", "--version"]
```

Create `infrastructure/images/node-tool/VERSION` with the content
`${yyyy}${mm}${dd}-${hash}`.

Bake the Dockerfile and check that the helper resolved the image pin:

```shell
DOCKER_IMAGE=node-tool make docker-bake-dockerfile
grep '^ARG NODE_VERSION=.*@sha256:' infrastructure/images/node-tool/Dockerfile.effective
```

Build and run the image. The run command prints the Node version:

```shell
DOCKER_IMAGE=node-tool make docker-build
DOCKER_IMAGE=node-tool make docker-run
```

Commit the `Dockerfile` and `VERSION`. `Dockerfile.effective` and `.version` are
generated by the build. Do not commit them. Ignore generated Dockerfiles in the
project that uses this template.

### Pin a new base image

The example above reuses an existing `node` pin. For a different base image,
choose a published tag and resolve its digest:

```shell
docker buildx imagetools inspect IMAGE:TAG --format '{{.Manifest.Digest}}'
```

Replace `IMAGE` and `TAG` with the image name and tag you chose. Add the exact
image name as a key in [mise.toml](../../mise.toml)'s `[_.docker]` table with
the value `TAG@sha256:DIGEST`. Keep a real tag as the Dockerfile `ARG` default,
and use that argument in `FROM IMAGE:${BASE_VERSION}`. The helper matches the
`FROM` image name to `[_.docker]` and rewrites the argument in
`Dockerfile.effective`. Run `make docker-bake-dockerfile` with the image name and
directory as in the example above, then inspect the generated `ARG` for the
digest. See [Update Dependencies](Update_Dependencies.md#docker-images) for the
release cooldown and digest checks. Commit the source Dockerfile and
`mise.toml`, not `Dockerfile.effective`.

### Testing your image

For the quick-start image, `DOCKER_IMAGE=my-shiny-app make docker-run` should
print `hello world` and exit successfully. The template's
`make docker-test-suite-run` tests its Docker helpers, not your image. Add
project-specific tests for your application's behaviour. For long-running
services, [Testcontainers](https://testcontainers.com/) can start an image from
your project's test suite.

Good project-specific image tests:

- Start the tag produced by `make docker-build`, rather than a different local
  image
- Wait for the service to be ready, using a log message, listening port, HTTP
  endpoint or `HEALTHCHECK`; container start alone does not prove readiness
- Check behaviour through the application's real interface
- Run the tests after building the image, before publishing it

## Conventions

### Versioning

You can specify the version tags that the automated build process applies to
your images with a `VERSION` file. This file must be located adjacent to the
`Dockerfile` where each image is defined.

It may be a "_statically defined_" version, such as `1.2.3`, `20230601`, etc.,
or a "_dynamic pattern_" based on the current time and commit hash, e.g.
`${yyyy}${mm}${dd}${HH}${MM}${SS}-${hash}`. This pattern will be substituted
during the build process to create a `.version` file in the same directory,
containing effective content like `20230601153000-123abcd`. See
[this function](https://github.com/nhs-england-tools/repository-template/blob/main/scripts/docker/docker.lib.sh#L118)
for what template substitutions are available.

This file is then used by functions defined in
[docker.lib.sh](../../scripts/docker/docker.lib.sh) but is ignored by Git, and
is not checked in with other files.

Support for multiple version entries is provided. For instance, if the `VERSION`
file contains:

```text
${yyyy}${mm}${dd}
${yyyy}${mm}${dd}${HH}${MM}
${yyyy}${mm}${dd}-${hash}
squirrel
```

The corresponding `.version` file generated by the `docker-build` function may
appear as:

```text
20230601
202306011530
20230601-123abcd
squirrel
```

In this case, the image is tagged with all four versions and `latest`. Run
`make docker-push` with the same image name and directory to push those tags.
This versioning approach is useful for projects with multiple deployments per
day.

> [!NOTE]<br> The preferred pattern for versioning is
> `${yyyy}${mm}${dd}${HH}${MM}` or/and `${yyyy}${mm}${dd}-${hash}` for projects
> with a cadence of multiple deployments per day. This is compatible with the
> [Calendar Versioning / CalVer](https://calver.org/) convention.

Base image versions are maintained in the [mise.toml](../../mise.toml) file's
`[_.docker]` table, located in the project's top-level directory. The format is
as follows:

```toml
[_.docker]
"image/name" = "1.0.0@sha256:1234567890...abcdef"
```

Each entry must be a single-line `"image/name" = "version"` pair. Entries in any
other form, for example multi-line strings, arrays or inline tables, are
ignored. `docker-get-image-version-and-pull` matches the image name exactly, so
a lookup for `node` never returns the pin for `cimg/node`.

When an image has a matching pin in `[_.docker]`, the `docker-build` function
rewrites its `ARG ..._VERSION=...` default in `Dockerfile.effective`, for example
turning `ARG PYTHON_VERSION=3.11.0` into
`ARG PYTHON_VERSION=1.0.0@sha256:1234567890...abcdef` for a
`FROM python:${PYTHON_VERSION}` instruction if you add a `python` image pin.
Additionally, the
[Dockerfile.metadata](../../scripts/docker/Dockerfile.metadata) file will be
appended to the end of the `Dockerfile.effective` created by the process.

The reason we do this is so that the deployment version is source-controlled,
but the tooling does not interfere with using a more recent Docker image during
local development before the new version can be added to the `mise.toml` file.
It also serves as a clean way of templating Docker image definition. The
`[_.docker]` table lives under the `[_]` key, which mise never uses for
toolchain resolution. Its presence does mean mise asks for `mise.toml` to be
trusted once per clone. Review the file and run `mise trust mise.toml` before
`make config`, which stops until you do, then installs the pinned native
toolchain and pulls every pinned Docker helper image locally.

`docker-pull-pinned-images` uses the first operational runtime of Docker then
Podman, where operational means `<runtime> info` succeeds within
`CONTAINER_INFO_TIMEOUT` seconds (default `10`). When neither is installed and
operational it prints a warning and succeeds, so `make config` still works on a
machine without a container runtime. When a runtime is operational, the first
failed pull or tag fails the target with that command's exit status and the
remaining images are not pulled. Only this pull step falls back to Podman. The
scripts that run the helper images call `docker` directly, so on a Podman-only
machine provide a `docker` command, for example through `podman-docker`.

### Variables

Set the `docker_image` or `DOCKER_IMAGE` variable for your image. Alternatively,
you can use their shorthand versions, `image` or `IMAGE`. To emphasize that it
is a global variable, using the uppercase version is recommended, depending on
your implementation.

### Platform architecture

For cross-platform image support, the `--platform linux/amd64` flag is used to
build Docker images, enabling containers to run without any changes on both
`amd64` and `arm64` architectures (via emulation).

### `Dockerignore` file

If you need to exclude files from a `COPY` command, put a
[`Dockerfile.dockerignore`](https://docs.docker.com/build/building/context/#filename-and-location)
file next to the relevant `Dockerfile`. They do not live in the root directory.
Any paths within `Dockerfile.dockerignore` must be relative to the repository
root.
