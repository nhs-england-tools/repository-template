# Repository Template Tutorial

This repository template contains a lot of material, and provides a
lot of functionality out of the box.  You might feel intimidated and
confused by the sheer number of files in it, and not know where to
look to get what you need done.

This tutorial is to walk you through the steps of getting a basic
Hello-World-style app into production, to show you where to find the
functionality you need and to demystify some of the content so that
you can get the most out of it.

We'll be building a python FastAPI server component with a NextJS
front-end.  Don't worry if you're not familiar with those particular
bits of technology. You don't need to understand them to understand
the tutorial.

I *will* assume familiarity with `git` itself.

## First things first

You will need certain tools to be installed in order to use the tools
in the repository template.  They are:

 - Docker or Podman, with the local agent running.
 - docker-compose.
 - The gnu coreutils.
 - Gnu make.

These are some of the tools that the engineering community assumes you
will have for compatibility with a wide range of projects and
products, so install them if you haven't already.

We do not assume, dictate, or otherwite hint at the correct text
editor for you to be using.  We just silently judge you for your
choice.

## Cloning the template

The first step to your brand new app is to clone the repository.  For
the purposes of this tutorial, we're going to clone it into your
personal account rather than into any of the NHS github
organisations. That's not what you'd be doing for anything we want to
go into production, but it means you can keep it as a reference and we
don't need to worry about naming collisions.

Go to https://github.com/nhs-england-tools/repository-template in your
browser, and click the green button marked `Use this template`. From
the dropdown that appears, select `Create a new repository`.

You will be taken to github's `Create a new repository` page.  You
might notice that this is the same page as github shows you when you
create an ordinary repository in the web user interface, but pay
attention to the `Repository template` field: you will see that it is
pre-populated with the `nhs-england-tools/repository-template` value.
That is as we want, so leave it as is.

Leave the `Include all branches` checkbox unticked.

Under `Owner`, select yourself from the `Choose an owner` dropdown.
Visibility options will appear under the Description field.  The
repository is MIT-licensed, and we're working in the open, so you
don't need to worry about this being a public repository.  You can
make it private if you prefer.

Under `Repository name`, give the repository a name of
`nhset-hello-world`.

[TODO: This means the SonarCloud integration won't work, but we can't
get around that without being able to make repositories in a different
org.]

If a description will help you remember the purpose of this project in
the future, put something meaningful to you in the `Description`
field.

Click the green `Create repository` button, and github will show you a
loading page while your new instance of the repository is created.

Now that you have your repository, clone it to your local machine for
the next step.

## Python time

For our Python application, we will be building an API endpoint which
returns a JSON blob that looks like this:

```json
{
  "message": "Hello World at 2023-09-01T15:36:12"
}
```

To isolate ourselves from anything else that's installed on your
machine, and to limit the dependencies we need you to install, we're
going to develop the endpoint in Docker.

First, assuming you have `cd`'d into your local repository's root,
make a directory for the API component:

```shell
$ mkdir api
```

Because we are good developers who like tests, we don't want to write
our server component without a test that we have seen fail.  I'm going
to shortcut the usual TDD cycle here a little, for clarity's sake, and
jump straight into a complete failing test that exercises the full
endpoint.  Edit `api/test_main.py` and add the following:

```python
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_get_main():
	response = client.get('/')
	assert response.status_code == 200
	assert response.json() == {"message": "Hello World"}
```

Again shortcutting the process slightly, let's jump straight to a
server component that does function, but that will fail the test, so
we can see what that looks like.

Edit `api/main.py` and add this:

```python
from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def get_main():
	return {"message": "Goodbye World"}
```

To build a local version of this which runs, we need to tell python
what the dependencies are.  Edit `api/requirements.txt` and add:

```
fastapi
```

Edit `api/test_requirements.txt` and add:

```
pytest
```

Now we need to define the images. Because we recommend keeping these
things in well-defined places, we expect to find image definitions
under `infrastructure/images`. Make the directory
`infrastructure/images/api`, to name it after the component you're
building, and edit `infrastructure/images/api/Dockerfile` to contain
this:

```Dockerfile
from python:slim as base

run mkdir /opt/api
workdir /opt/api
env PYTHONUNBUFFERED="1"

from base as builder
copy ./requirements.txt /opt/api/requirements.txt
run python -m pip install --requirement /opt/api/requirements.txt  --no-cache-dir --prefix=/packages

from base as prod
copy --from=builder /packages /usr/local
copy ./ /opt/api
user nobody
expose 8000
cmd ["uvicorn", "main:app", "--host", "0", "--port", "8000"]
```

It can be very hard to use the same Dockerfile for both testing and
running the same code.  Usually we want to avoid installing the
packages needed for testing into the artefact we want to run in
production.  I'm not going to try combining them: it's easier here to
have two separate Dockerfiles and to live with a little duplication.

Edit `infrastructure/images/api/Dockerfile.test` to contain:

```Dockerfile
from python:slim as base

run mkdir /opt/api
workdir /opt/api
env PYTHONUNBUFFERED="1"

copy ./ /opt/api
run python -m pip install --requirement /opt/api/requirements.txt
run python -m pip install --requirement /opt/api/test_requirements.txt

cmd ["sleep", "infinity"]
```

To tie the Dockerfile definitions together, there's a top-level
`docker-compose.yaml` file which you can edit.  Change it so that it
looks like this:

```yaml
version: "3.8"

x-api-code-volume: &api-code-volume
  type: bind
  source: "./api"
  target: "/opt/api"

services:
  api: &api
    build:
      context: api
      dockerfile: ../infrastructure/images/api/Dockerfile
    ports:
      - "8000:8000"
    volumes:
      - *api-code-volume
  unit_test:
    build:
      context: api
      dockerfile: ../infrastructure/images/api/Dockerfile.test
    volumes:
      - *api-code-volume
```

Let's check this works.  Run this command, to build the image and
execute the server command we've defined:

```shell
$ make up
```

This is one of a number of `make` tasks we've predefined to make
working with the repository template as painless as possible.  If you
take a look in `Makefile` you'll see where the make tasks themselves
are defined, but all the make tasks do is to shell out to scripts
under `scripts/projecthooks/` that do the actual work.  If you need to
customise how you run the project, the idea is that you can change
those scripts to do what you want without having to dig into `make`
syntax.

Now, in another terminal, we can check that the response is what we
expect:

```shell
 $ curl -i localhost:8000
HTTP/1.1 200 OK
date: Fri, 01 Sep 2023 16:52:58 GMT
server: uvicorn
content-length: 27
content-type: application/json

{"message":"Goodbye World"}
```

Success!

Well, not quite.  We wrote a test, but how do we run it?  Try running
`make test-unit`.  You should see output that looks like this:

```
 $ make test-unit
Unit tests are not yet implemented. See scripts/testhooks/unit.sh for more.
```

Open up `scripts/testhooks/unit.sh` and replace the last line with this:

```sh
docker-compose exec unit_test pytest
```

Now, run `make test-unit` again.  Now you should see this:

```
=============================== test session starts ===============================
collected 1 item

test_main.py F                                                              [100%]

==================================== FAILURES =====================================
__________________________________ test_get_main __________________________________

    def test_get_main():
    	response = client.get('/')
    	assert response.status_code == 200
>   	assert response.json() == {"message": "Hello World"}
E    AssertionError: assert {'message': 'Goodbye World'} == {'message': 'Hello World'}
E      Differing items:
E      {'message': 'Goodbye World'} != {'message': 'Hello World'}
E      Use -v to get more diff

test_main.py:9: AssertionError
============================= short test summary info =============================
FAILED test_main.py::test_get_main - AssertionError: assert {'message': 'Goodbye World'} == {'message': 'Hello World'}
================================ 1 failed in 0.39s ================================
```

Our test has failed!  That's exactly what we want and expect: the
message we wrote in `main.py` isn't what the spec said in
`test_main.py`.  Edit `main.py` so that the message is correct:

```python
...
@app.get("/")
async def get_main():
	return {"message": "Hello World"}
```

and run `make test-unit` again:

```
$ make test
============================== test session starts ===============================
platform linux -- Python 3.11.5, pytest-7.4.1, pluggy-1.3.0
rootdir: /opt/api
plugins: anyio-3.7.1
collected 1 item

test_main.py .                                                             [100%]

=============================== 1 passed in 0.31s ================================
```

The test passed!  Now, you might be wondering what other test tasks
you have available, predefined.  Try running just `make test`:

```
$ make test
============================== test session starts ===============================
platform linux -- Python 3.11.5, pytest-7.4.1, pluggy-1.3.0
rootdir: /opt/api
plugins: anyio-3.7.1
collected 1 item

test_main.py .                                                             [100%]

=============================== 1 passed in 0.32s ================================
make test-lint not implemented: ./scripts/testhooks/lint.sh not found
make test-coverage not implemented: ./scripts/testhooks/coverage.sh not found
make test-contract not implemented: ./scripts/testhooks/contract.sh not found
make test-security not implemented: ./scripts/testhooks/security.sh not found
make test-ui not implemented: ./scripts/testhooks/ui.sh not found
make test-ui-performance not implemented: ./scripts/testhooks/ui-performance.sh not found
make test-integration not implemented: ./scripts/testhooks/integration.sh not found
make test-accessibility not implemented: ./scripts/testhooks/accessibility.sh not found
make test-capacity not implemented: ./scripts/testhooks/capacity.sh not found
make test-soak not implemented: ./scripts/testhooks/soak.sh not found
make test-response-time not implemented: ./scripts/testhooks/response-time.sh not found
```

There you have the `make test-unit` output, along with each of the
other test types telling you that it hasn't yet been implemented, and
where to put the file you'd need to edit to implement it.

If you want some more information about what each is for, run `make help`.

That's as far as we'll take the unit testing for the moment.
