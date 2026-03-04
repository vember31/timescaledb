# syntax=docker/dockerfile:1

# PG_MAJOR: PostgreSQL major version (used for package names, e.g. 18)
ARG PG_MAJOR=18
# PG_IMAGE_TAG: CNPG base image tag — pin to a specific minor version (e.g. 18.3)
# Defaults to PG_MAJOR so it tracks the latest minor release of that major.
ARG PG_IMAGE_TAG=${PG_MAJOR}
# DISTRO: Debian codename used in the CNPG base image tag and the TimescaleDB apt repo (e.g. trixie)
ARG DISTRO=trixie

FROM ghcr.io/cloudnative-pg/postgresql:${PG_IMAGE_TAG}-minimal-${DISTRO} AS builder

# Re-declare after FROM so the values are available in this build stage
ARG PG_MAJOR=18
ARG DISTRO=trixie

USER 0

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        curl \
        gnupg \
    ; \
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

# Extension image: contains only the extension files, no full PostgreSQL installation.
# CNPG mounts this as an OCI image volume and automatically appends the paths to
# extension_control_path and dynamic_library_path (PostgreSQL 18 GUCs).
# Requires CNPG >= 1.27 and Kubernetes >= 1.33 (ImageVolume feature gate) or >= 1.35 (GA).
#
# Note: TimescaleDB still requires shared_preload_libraries in the Cluster manifest:
#   postgresql:
#     shared_preload_libraries:
#       - timescaledb
FROM scratch
ARG PG_MAJOR=18

COPY --from=builder /usr/lib/postgresql/${PG_MAJOR}/lib/timescaledb*.so /lib/
COPY --from=builder /usr/share/postgresql/${PG_MAJOR}/extension/timescaledb* /share/extension/

USER 65532:65532
