# timescaledb-cnpg

[TimescaleDB](https://www.timescale.com/) extension images for [CloudNativePG](https://cloudnative-pg.io/) (CNPG), built using the [ImageVolume extension model](https://cloudnative-pg.io/docs/1.28/imagevolume_extensions/) introduced in CNPG 1.27.

Rather than shipping a custom full PostgreSQL image, this repo produces a lightweight `FROM scratch` image containing only the TimescaleDB shared libraries and extension control files. CNPG mounts it as an OCI image volume and wires up the extension paths automatically.

Images are published to GitHub Container Registry and rebuilt automatically every week to include the latest TimescaleDB patch releases and OS security updates.

**Requirements:** CNPG ≥ 1.27, Kubernetes ≥ 1.33 (ImageVolume feature gate) or ≥ 1.35 (GA).

---

## Image tags

Images are published to `ghcr.io/<owner>/<repo>`.

| Tag pattern | When it's updated | Use case |
|---|---|---|
| `pg18` | Every push to `main` + weekly schedule | Latest — suitable for non-production |
| `v1.2.3-pg18` | On a `v*.*.*` git tag | Immutable release — use in production |
| `sha-abc1234-pg18` | Every build | Pinned to a specific commit |

The `pg18` floating tag is the most convenient starting point. Pin to a `sha-` or `v`-prefixed tag for production stability.

---

## Using the image in a CNPG cluster

### 1. Make the GHCR package public (or configure a pull secret)

In your repository on GitHub: **Settings → Packages → Change visibility → Public**.

For private images, create a Kubernetes pull secret and reference it in the `Cluster` manifest.

### 2. Enable TimescaleDB in the CNPG `Cluster` manifest

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: my-timescale-cluster
  namespace: default
spec:
  instances: 3

  # Use the standard CNPG image — no custom imageName needed
  imageName: ghcr.io/cloudnative-pg/postgresql:18.3-standard-trixie

  postgresql:
    parameters:
      max_locks_per_transaction: "128"           # recommended for TimescaleDB
      timescaledb.max_background_workers: "32"
      timescaledb.max_tuples_decompressed_per_dml_transaction: "0"
      timescaledb.telemetry_level: "off"
    # TimescaleDB must be loaded at startup; this cannot be set automatically
    # by the extension image mechanism
    shared_preload_libraries:
      - timescaledb
    extensions:
      - name: timescaledb
        image:
          reference: ghcr.io/<owner>/<repo>:pg18

  storage:
    size: 20Gi
```

### 3. Create the extension in your database

Connect to the primary and run:

```sql
CREATE EXTENSION IF NOT EXISTS timescaledb;
```

---

## Building locally

Prerequisites: Docker with Buildx.

```bash
# Build for PG 18 (default)
docker build -t timescaledb-cnpg:pg18 .

# Pin to a specific CNPG minor release
docker build --build-arg PG_IMAGE_TAG=18.3 -t timescaledb-cnpg:pg18 .

# Override the Debian codename (for base image and apt repo)
docker build --build-arg DISTRO=bookworm -t timescaledb-cnpg:pg18 .
```

---

## How it works

The `Dockerfile` uses a two-stage build:

1. **Builder stage**: starts from `ghcr.io/cloudnative-pg/postgresql:<tag>-minimal-<distro>`, adds the Timescale apt repository, and installs `timescaledb-2-postgresql-<PG_MAJOR>`
2. **Final stage**: `FROM scratch` — copies only the extension's shared libraries (`/lib/timescaledb*.so`) and control files (`/share/extension/timescaledb*`)

CNPG mounts the final image as an OCI image volume and automatically appends its paths to `extension_control_path` and `dynamic_library_path` (PostgreSQL 18 GUCs). The standard CNPG PostgreSQL image is used as the cluster's operand; no custom `imageName` is required.

---

## Adding more PostgreSQL versions

Edit the matrix in `.github/workflows/build.yml`:

```yaml
matrix:
  include:
    - pg_major: "18"
      pg_image_tag: "18.3"
      distro: "trixie"
    - pg_major: "17"
      pg_image_tag: "17.5"
      distro: "bookworm"
```

Each version produces its own set of tags (e.g. `pg17`, `v1.2.3-pg17`).
