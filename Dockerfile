# syntax=docker/dockerfile:1

# PG_MAJOR: PostgreSQL major version to target (must match the CNPG base image tag)
ARG PG_MAJOR=18

FROM ghcr.io/cloudnative-pg/postgresql:${PG_MAJOR}

# Re-declare after FROM so the value is available in the build stage
ARG PG_MAJOR=18

# REPO_DISTRO: Debian codename for the TimescaleDB apt repo.
# Defaults to empty — in which case the OS codename is auto-detected at build time.
# Override if packagecloud.io/timescale does not yet carry packages for your distro
# (e.g. --build-arg REPO_DISTRO=bookworm).
ARG REPO_DISTRO=

USER root

RUN set -eux; \
    # Install prerequisites
    apt-get update; \
    apt-get install -y --no-install-recommends \
        curl \
        gnupg \
    ; \
    \
    # Determine the repo distro — use the override if set, otherwise read from OS
    if [ -n "${REPO_DISTRO}" ]; then \
        DISTRO="${REPO_DISTRO}"; \
    else \
        . /etc/os-release; \
        DISTRO="${VERSION_CODENAME}"; \
    fi; \
    \
    # Add the Timescale apt repository
    curl -fsSL https://packagecloud.io/timescale/timescaledb/gpgkey \
        | gpg --dearmor -o /etc/apt/trusted.gpg.d/timescaledb.gpg; \
    echo "deb https://packagecloud.io/timescale/timescaledb/debian/ ${DISTRO} main" \
        > /etc/apt/sources.list.d/timescaledb.list; \
    \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        "timescaledb-2-postgresql-${PG_MAJOR}" \
    ; \
    \
    # Clean up
    apt-get purge -y curl gnupg; \
    apt-get autoremove -y; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# CNPG images run as UID 26 (postgres)
USER 26
