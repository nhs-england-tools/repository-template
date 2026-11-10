# Run services with Docker Compose 🐳

- [Run services with Docker Compose 🐳](#run-services-with-docker-compose-)
  - [Prerequisites 📋](#prerequisites-)
  - [Start a small service 🚀](#start-a-small-service-)
  - [Choose the Compose project 📦](#choose-the-compose-project-)
  - [Build, inspect and stop services 🔧](#build-inspect-and-stop-services-)
  - [Overrides and environment variables 🧩](#overrides-and-environment-variables-)
  - [Troubleshooting 🔍](#troubleshooting-)

The targets in [docker.mk](../../scripts/docker/docker.mk) wrap Docker Compose
for a project's local services. The template supplies the commands. Add your own
Compose file and application configuration.

## Prerequisites 📋

Complete the [quick start](../../README.md#quick-start-). Compose operations
require a working `docker` executable on `PATH` and a Compose provider that
supports Docker Compose v2 commands, including `up --wait`. Start the Docker
daemon, or start the Podman machine where needed. For Podman, provide a `docker`
executable as described in [Build Docker images](Build_Docker_images.md), and
install an external Compose provider such as `docker-compose` or
`podman-compose` as described in
[Podman's Compose documentation](https://docs.podman.io/en/latest/markdown/podman-compose.1.html).
Check both commands before starting:

```shell
docker info
docker compose version
```

These targets call `docker compose` directly. A shell alias does not apply to
Make recipes, and the Podman fallback used to pull toolchain images does not
apply to Compose.

## Start a small service 🚀

Run these commands from the repository root in a Bash shell. This example
creates a local HTTP service with its own image and a health check. If your
interactive shell is different, enter `bash` first.

Resolve the Python image already pinned in `mise.toml`. The helper pulls it if
needed and prints its tag and digest. Keep this variable in the shell used for
the commands below:

```shell
source scripts/docker/docker.lib.sh
COMPOSE_PYTHON_IMAGE=$(name=python docker-get-image-version-and-pull)
export COMPOSE_PYTHON_IMAGE
mkdir -p infrastructure/compose-demo
```

Create `infrastructure/compose-demo/index.html`:

```html
<h1>Compose is running</h1>
```

Create `infrastructure/compose-demo/Dockerfile`:

```dockerfile
ARG PYTHON_IMAGE
FROM ${PYTHON_IMAGE}
WORKDIR /srv
COPY index.html .
USER 65534:65534
EXPOSE 8000
CMD ["python", "-m", "http.server", "8000", "--bind", "0.0.0.0"]
```

Create `infrastructure/compose-demo/compose.yaml`:

```yaml
services:
  web:
    platform: linux/amd64
    build:
      context: .
      args:
        PYTHON_IMAGE: ${COMPOSE_PYTHON_IMAGE:?Export the pinned Python image first}
    ports:
      - "127.0.0.1:8080:8000"
    healthcheck:
      test:
        - CMD
        - python
        - -c
        - "import urllib.request;
          urllib.request.urlopen('http://127.0.0.1:8000')"
      interval: 2s
      timeout: 2s
      retries: 15
```

Check the Compose configuration, build and start the service:

```shell
docker compose -f infrastructure/compose-demo/compose.yaml config --quiet
make docker-compose-build dir=infrastructure/compose-demo project=template-demo
make docker-compose-up dir=infrastructure/compose-demo project=template-demo
make docker-compose-status dir=infrastructure/compose-demo project=template-demo
curl --fail http://127.0.0.1:8080/
```

The request should return `<h1>Compose is running</h1>`. The service is bound to
the local machine. The explicit platform matches the template's helper-image
pulls and may use emulation on an ARM machine.

Compose builds the Dockerfile directly. It does not run the template's image
linting, `Dockerfile.effective` generation, version tagging or metadata helpers.
This example passes the pinned base image as a build argument explicitly. See
[Build Docker images](Build_Docker_images.md) when using those helpers to build
images separately, then reference the resulting image in your Compose file.

## Choose the Compose project 📦

Use the same directory, file and project selections for build, up, logs and
cleanup:

| Option             | Meaning                                                                                                |
| ------------------ | ------------------------------------------------------------------------------------------------------ |
| `dir=path`         | Directory containing a Compose file. Paths are relative to the repository root.                        |
| `compose_dir=path` | Explicit directory option, which takes precedence over `dir`.                                          |
| `file=path`        | A particular Compose file, passed to Compose with `--file`. Use it instead of either directory option. |
| `project=name`     | Passes `--project-name` to Compose. Use a different name to keep separate local stacks apart.          |

Without a directory or file option, and when `COMPOSE_FILE` is unset, the
wrapper looks for a top-level Compose file first. Otherwise, it selects the only
directory containing one among tracked and non-ignored untracked files. It
recognises `compose.yaml`, `compose.yml`, `docker-compose.yaml` and
`docker-compose.yml`. Multiple matching directories require an explicit
selection. The top-level check also sees an ignored Compose file.

For example, select a file directly:

```shell
make docker-compose-status file=infrastructure/compose-demo/compose.yaml project=template-demo
```

`DOCKER_IMAGE` selects individual image-helper operations. It is not needed for
the Compose targets.

## Build, inspect and stop services 🔧

| Target                  | Compose operation                           |
| ----------------------- | ------------------------------------------- |
| `docker-compose-build`  | `build`                                     |
| `docker-compose-up`     | `up --detach --wait`                        |
| `docker-compose-status` | `ps`                                        |
| `docker-compose-logs`   | `logs --no-color --tail=100`                |
| `docker-compose-down`   | `down --remove-orphans`                     |
| `docker-compose-clean`  | The same operation as `docker-compose-down` |

Run `build` before `up` after changing an image's source. The `up` target has no
`--build` flag. It waits for services to be running or healthy. Define a health
check when readiness requires more than a running process.

Read recent logs and stop the example when finished:

```shell
make docker-compose-logs dir=infrastructure/compose-demo project=template-demo
make docker-compose-down dir=infrastructure/compose-demo project=template-demo
```

The logs target prints a snapshot. For live logs, use Compose directly with the
same project and file selection:

```shell
docker compose -f infrastructure/compose-demo/compose.yaml --project-name template-demo logs --follow
```

Both `down` and `clean` remove the selected project's containers, orphaned
containers and network. They retain volumes and built images. They act
immediately and do not use `CONFIRM`. They also leave your source files in
place. Root `make clean` performs different file and image cleanup, described in
[Use Bash and Make](Use_Bash_and_Make.md#clean-up-files-and-docker-resources-).

## Overrides and environment variables 🧩

With directory discovery or `dir`, the wrapper runs Compose from the selected
directory, preserving its normal `.env` and `compose.override.yaml` lookup. With
`file`, it runs from the repository root and lets Compose resolve the explicit
file. Include overrides explicitly when using `file`.

You can also use `COMPOSE_FILE` to select multiple files. For example, in a Bash
shell on macOS or Linux, after creating a local override:

```shell
COMPOSE_FILE=infrastructure/compose-demo/compose.yaml:infrastructure/compose-demo/compose.local.yaml \
  make docker-compose-up project=template-demo
```

An explicit `project` overrides `COMPOSE_PROJECT_NAME`. Without it, Compose
chooses its usual project name. Keep any local environment files containing
secrets out of Git. The example's `COMPOSE_PYTHON_IMAGE` is an image reference,
not a secret. Export it again when opening a new shell, including before running
`down`, because Compose validates the configuration for that command.

## Troubleshooting 🔍

| Symptom                           | Action                                                                                                           |
| --------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| No Compose file found             | Create the file or pass an existing `dir` or `file`. Nested ignored files are excluded from automatic discovery. |
| Several Compose directories found | Choose one with `dir`, or pass a particular `file`.                                                              |
| Both file and directory supplied  | Keep one selection method. `file` cannot be combined with `dir` or `compose_dir`.                                |
| Docker or Compose unavailable     | Check `docker info` and `docker compose version`. These targets do not install the runtime.                      |
| Port 8080 already in use          | Change the host port in the example's `ports` entry and use that port in the request.                            |
| `up` reports an unhealthy service | Inspect status and logs, then check the health-check command and application dependencies.                       |
| Services seem to be missing       | Use the same file, directory and project name that started them.                                                 |
| A source change is absent         | Run `docker-compose-build` again before `docker-compose-up`.                                                     |

Use `VERBOSE=true` on a Make target to see the wrapper commands. Compose
failures are returned to Make, so a failed command produces a non-zero exit
status.
