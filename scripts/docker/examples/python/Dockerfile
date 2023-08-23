# `*:latest` will be replaced with a corresponding version stored in the '.tool-versions' file
# hadolint ignore=DL3007
FROM python:latest as base

# === Builder ==================================================================

FROM base AS builder
COPY ./assets/hello_world/requirements.txt /requirements.txt
WORKDIR /packages
RUN set -eux; \
    \
    # Install dependencies
    pip install \
        --requirement /requirements.txt \
        --prefix=/packages \
        --no-warn-script-location \
        --no-cache-dir

# === Runtime ==================================================================

FROM base
ENV \
    LANG="C.UTF-8" \
    LC_ALL="C.UTF-8" \
    PYTHONDONTWRITEBYTECODE="1" \
    PYTHONUNBUFFERED="1" \
    TZ="UTC"
COPY --from=builder /packages /usr/local
COPY ./assets/hello_world /hello_world
WORKDIR /hello_world
USER nobody
CMD [ "python", "app.py" ]
EXPOSE 8000
