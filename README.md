# timescaledb-cnpg

Custom PostgreSQL container images with [TimescaleDB](https://www.timescale.com/) pre-installed, built for use with [CloudNativePG](https://cloudnative-pg.io/) (CNPG).

Images are published to GitHub Container Registry and rebuilt automatically every week to include the latest TimescaleDB patch releases and OS security updates.

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

  # Reference the custom image
  imageName: ghcr.io/<owner>/<repo>:pg18

  postgresql:
    parameters:
      # TimescaleDB must be loaded at startup
      shared_preload_libraries: "timescaledb"

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

# Build for a different PG major version
docker build --build-arg PG_MAJOR=17 -t timescaledb-cnpg:pg17 .

# Override the apt repo distro if packagecloud doesn't carry packages
# for your base image's Debian codename yet
docker build --build-arg REPO_DISTRO=bookworm -t timescaledb-cnpg:pg18 .
```

---

## How it works

The `Dockerfile`:

1. Starts from the official CNPG base image (`ghcr.io/cloudnative-pg/postgresql:<PG_MAJOR>`)
2. Adds the Timescale apt repository (packagecloud.io/timescale), auto-detecting the Debian codename from the base image
3. Installs `timescaledb-2-postgresql-<PG_MAJOR>` (latest available)
4. Drops back to the CNPG postgres user (UID 26)

All CNPG tooling (Barman Cloud, pg_basebackup, etc.) is inherited unchanged from the base image.

---

## Adding more PostgreSQL versions

Edit the matrix in `.github/workflows/build.yml`:

```yaml
matrix:
  pg_major:
    - "18"
    - "17"   # add more versions here
```

Each version produces its own set of tags (e.g. `pg17`, `v1.2.3-pg17`).
