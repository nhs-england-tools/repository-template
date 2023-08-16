# `*:latest` will be replaced with a corresponding version stored in the '.tool-versions' file
# hadolint ignore=DL3007
FROM python:latest as base

# === Builder ==================================================================

FROM base AS builder
ENV \
    GOSU_VERSION="1.16"
COPY ./assets/hello_world/requirements.txt /requirements.txt
WORKDIR /packages
RUN set -eux; \
    \
    # Get base packages
    apk add --no-cache \
        ca-certificates \
        dpkg \
        gnupg \
        wget \
    && \
    \
    # Get gosu
    dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')" && \
    wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch" && \
    wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc" && \
    export GNUPGHOME="$(mktemp -d)" && \
    gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 && \
    gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu && \
    gpgconf --kill all && \
    rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc && \
    chmod +x /usr/local/bin/gosu && \
    \
    # Install dependencies
    pip install \
        --requirement /requirements.txt \
        --prefix=/packages \
        --no-warn-script-location \
        --no-cache-dir

# === Runtime ==================================================================

# NOSONAR
FROM base
ENV \
    LANG="C.UTF-8" \
    LC_ALL="C.UTF-8" \
    PYTHONDONTWRITEBYTECODE="1" \
    PYTHONUNBUFFERED="1" \
    SYSTEM_USER_GID="999" \
    SYSTEM_USER_UID="999" \
    SYSTEM_USER="example" \
    TZ="UTC"
COPY --from=builder /usr/local/bin/gosu /usr/local/bin/gosu
COPY --from=builder /packages /usr/local
COPY ./assets/hello_world /hello_world
WORKDIR /hello_world
RUN set -eux; \
    \
    # Configure system user
    ( deluser $SYSTEM_USER ||: ) && ( delgroup $SYSTEM_USER ||: ) && ( delgroup $(getent group $SYSTEM_USER_GID | sed -e "s/:x:$SYSTEM_USER_GID//g") ||: ) && \
    addgroup -S -g $SYSTEM_USER_GID $SYSTEM_USER && \
    adduser -H -D -s /bin/false -g "" -h /tmp -G $SYSTEM_USER -u $SYSTEM_USER_UID $SYSTEM_USER && \
    gosu nobody true
CMD [ "python", "app.py" ]
EXPOSE 8000
