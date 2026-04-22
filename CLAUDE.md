# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A thin wrapper around the official `elasticsearch` Docker image tailored for deployment on Railway (and similar managed container hosts where the kernel and volume mounts aren't under user control). There is no application code, no test suite, and no package manager — just a `Dockerfile` and the three config/script files it bakes in.

## Common commands

Build the image locally (pins to the default version from the Dockerfile):

```sh
docker build -t railway-elasticsearch .
```

Override the Elasticsearch version at build time:

```sh
docker build --build-arg ELASTICSEARCH_VERSION=8.19.10 -t railway-elasticsearch .
```

Run it locally against an ephemeral volume (mirrors Railway's root-owned mount by using a named volume; set an initial password via env):

```sh
docker run --rm -e ELASTIC_PASSWORD=changeme -p 9200:9200 -v esdata:/esdata railway-elasticsearch
```

## Architecture: why each file exists

The three non-Dockerfile files exist to work around constraints that Railway (and similar platforms) impose. Changing any of them without understanding the constraint will break the deploy.

- **`elasticsearch.yml`** — `node.store.allow_mmap: false` is the load-bearing line. Managed hosts don't let tenants raise `vm.max_map_count` from the kernel default of 65530 up to the 262144 Elasticsearch wants, so mmap is disabled entirely. The file also pins `path.data: /esdata` (matched by the entrypoint chown), enables xpack security, and configures an **anonymous user** (`anonymous_user` → `anonymous_role`) so Railway's healthcheck can hit the cluster without credentials.

- **`roles.yml`** — Defines `anonymous_role` with only the `monitor` cluster privilege. This is the minimum needed for `/_cluster/health` to succeed; do not broaden it.

- **`entrypoint-new.sh`** — Railway mounts persistent volumes as root, but the upstream image runs as uid 1000 and refuses to run as root. The entrypoint `sudo chown -R 1000 /esdata` fixes ownership, then execs the stock `docker-entrypoint.sh eswrapper` under `tini`. The Dockerfile's `RUN` step exists solely to install `sudo` and grant the `elasticsearch` user a narrow NOPASSWD sudoers entry for `/bin/chown` only — keep that sudoers rule tight.

The `USER 1000:0` directive and the `sudo chown` in the entrypoint are a pair: removing either one breaks startup.

## Version upgrades

Bump `ARG ELASTICSEARCH_VERSION` in the `Dockerfile`. Before upgrading across minor/major versions, consult the upstream upgrade manual linked from `README.md` (https://www.elastic.co/docs/deploy-manage/upgrade/deployment-or-cluster/upgrade-717) — Elasticsearch upgrades frequently require staged rolling procedures, and the config in `elasticsearch.yml` may need adjustment if deprecated settings are removed.
