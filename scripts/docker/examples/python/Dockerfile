FROM python:latest as base

# === Builder ==================================================================

FROM base AS builder
COPY ./assets/hello_world/requirements.txt /requirements.txt
WORKDIR /packages
RUN set -eux; \
    \
    pip install \
        --requirement /requirements.txt \
        --prefix=/packages \
        --no-warn-script-location \
        --no-cache-dir

# === Runtime ==================================================================

FROM base
COPY --from=builder /packages /usr/local
COPY ./assets/hello_world /hello_world
WORKDIR /hello_world
CMD [ "python", "app.py" ]
EXPOSE 8000
