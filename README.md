# neeythann/opencode-docker

Run [opencode](https://opencode.ai) in a Docker container with a persistent
session store, a non-root `dev` user, and optional `root` access via `su`.

## Contents

| File | Purpose |
| --- | --- |
| `Dockerfile` | Debian 13 image with dev tools and opencode installed system-wide |
| `docker-compose.yml` | Compose stack exposing `opencode web` on the host |
| `entrypoint.sh` | Sets the root password from `$ROOT_PASSWORD`, then drops to `dev` |
| `.env.example` | Template for required environment variables |
| `opencode/` | Mounted workspace (`/workspace` inside the container) |
| `k8s/` | Kubernetes manifests (Deployment, Service, PVC, ExternalSecret) |
| `LICENSE` | AGPL-3.0 |
| `THIRD_PARTY_NOTICES.md` | Licenses for opencode and the base image |

## Prerequisites

- Docker with the Compose plugin

## Setup

```sh
cp .env.example .env
$EDITOR .env
docker compose up -d --build
```

Open `http://<host>:4096`.

## Configuration

`.env` values:

| Variable | Required | Default | Description |
| --- | --- | --- | --- |
| `ROOT_PASSWORD` | yes | none | Password for `root` inside the container |
| `OPENCODE_SERVER_USERNAME` | no | `opencode` | Web server username |
| `PROJECT_DIR` | no | `.` | Host path mounted at `/workspace` |
| `OPENCODE_BIND` | no | `127.0.0.1` | Host address the port is published on |
| `OPENCODE_PORT` | no | `4096` | Published port, host and container |

### Other opencode variables

`docker-compose.yml` loads the entire `.env` with `env_file`, so any variable
you add there reaches the container. Add provider keys and opencode runtime
flags without editing `docker-compose.yml`.

Add entries to `.env` for anything opencode reads, for example:

```sh
# Provider credentials (auto-detected by opencode)
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
GEMINI_API_KEY=...

# Custom config / config dir
OPENCODE_CONFIG=/workspace/opencode.json
OPENCODE_CONFIG_DIR=/workspace/.opencode

# Server basic auth password (username via OPENCODE_SERVER_USERNAME)
OPENCODE_SERVER_PASSWORD=...
```

See `{env:...}` substitution in opencode's config for referencing these from
`opencode.json`.

`environment:` overrides values from `env_file`, so `BROWSER`,
`OPENCODE_SERVER_USERNAME`, and `ROOT_PASSWORD` keep their defaults and
validation.

### Host binding

`OPENCODE_BIND` sets the host address the port is published on. It defaults to
`127.0.0.1`, so the server is reachable only from the host itself. For remote
access, set it to a specific interface, such as a private VPN address:

```sh
OPENCODE_BIND=203.0.113.10
OPENCODE_PORT=4096
```

Avoid `0.0.0.0` on a host with a public IP. The `--hostname 0.0.0.0` inside the
container is fine: that namespace is private, and the host-side bind above is
what controls reachability.

## Usage

```sh
docker compose logs -f          # follow logs
docker compose exec opencode bash   # shell as dev
docker compose restart          # restart
docker compose down             # stop and remove
```

### Root access

From the `dev` shell:

```sh
su root
```

The root password is the value of `ROOT_PASSWORD`. `opencode` itself runs as
`dev` (uid 1000), so only interactive shells elevate.

## Data

Sessions, credentials, and snapshots persist in the named volume
`opencode-dev_opencode-data`, mounted at `/home/dev/.local/share/opencode`.

Back up the volume:

```sh
docker run --rm -v opencode-dev_opencode-data:/d -v "$PWD":/backup alpine \
  tar czf /backup/opencode-data.tgz -C /d .
```

Restore it:

```sh
docker volume create opencode-dev_opencode-data
docker run --rm -v opencode-dev_opencode-data:/d -v "$PWD":/backup alpine \
  sh -c 'tar xzf /backup/opencode-data.tgz -C /d && chown -R 1000:1000 /d'
```

## Kubernetes

Manifests live in `k8s/` and target the `default` namespace:

| File | Resource |
| --- | --- |
| `deployment.yaml` | `Deployment` running `opencode web`, `Recreate` strategy |
| `service.yaml` | `ClusterIP` Service on port 4096 |
| `pvc.yaml` | `PersistentVolumeClaim` for `/home/dev/.local/share/opencode` |
| `externalsecret.yaml` | ExternalSecret syncing keys into `opencode-secret` |

The Deployment reads `OPENCODE_SERVER_PASSWORD`, `ROOT_PASSWORD`, and
`OLLAMA_API_KEY` from the `opencode-secret` Secret. The ExternalSecret pulls
those keys from Vault at `opencode/prod`; adjust the path or property names to
match your store.

Apply:

```sh
kubectl apply -f k8s/
```

Reach it locally with a port-forward:

```sh
kubectl port-forward svc/opencode 4096:4096
```

Notes:

- The container is read-only except for the mounted volume, so the `Recreate`
  strategy avoids two pods claiming the same `ReadWriteOnce` PVC.
- The Deployment sets `fsGroup: 1000`, so the PersistentVolume is writable by
  the `dev` user. A storage class that supports `fsGroup` is required.
- The image is published to GHCR as `ghcr.io/neeythann/opencode-docker` by the
  workflow in `.github/workflows/docker-image.yml`. If the package is private,
  add an `imagePullSecret` to the Deployment.

## Notes

- The `xdg-open` error in the logs is harmless: `BROWSER=none` prevents a real
  browser launch, and the container has no opener installed.
- The image runs `opencode web` as `dev`; data on the volume is owned by
  uid/gid `1000`.

## License

AGPL-3.0. See `LICENSE`. The image bundles opencode and Debian packages under
their own licenses; see `THIRD_PARTY_NOTICES.md`.

Running this project as a network service means the AGPL's network clause
applies: users interacting with it over a network must be offered the
corresponding source. This repository is that source.
