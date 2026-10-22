# bleed2002/nextcloud

Personal, all-in-one (nginx + PHP-FPM + Nextcloud) Docker image based on Alpine Linux.

Originally forked from [Wonderfall/docker-nextcloud](https://github.com/Wonderfall/docker-nextcloud) (unmaintained),
now tracking [hoellen/docker-nextcloud](https://github.com/hoellen/docker-nextcloud) as upstream.
For general image documentation (environment variables, volumes, ports, usage) see the
[upstream README](https://github.com/hoellen/docker-nextcloud#readme) – it still applies.

Images are published to Docker Hub: [`bleed2002/nextcloud`](https://hub.docker.com/r/bleed2002/nextcloud).

## Differences to upstream

- **Separate PHP base image** (`Dockerfile.ng-php-base`) built with
  [install-php-extensions](https://github.com/mlocati/docker-php-extension-installer)
  instead of compiling extensions in every Nextcloud build. Tagged
  `bleed2002/nextcloud:php-<php>-fpm-alpine<alpine>`.
- **One Dockerfile per Nextcloud major** (`Dockerfile.ng-v<major>`), so several majors
  can be built and kept side by side (e.g. for step-by-step upgrades). Tagged
  `bleed2002/nextcloud:ng-v<major>` and `ng-v<full version>`.
- Snuffleupagus isn't installed in the PHP base image (`PHP_HARDENING=false`); `dockerize` is included.
- Extended `run.sh`: on upgrade it empties `nextcloud.log` and runs `occ upgrade`,
  `db:add-missing-*`, `db:convert-filecache-bigint`, `maintenance:repair --include-expensive`
  and `app:update --all`.
- `occ` wrapper uses `CRON_MEMORY_LIMIT`; nginx sends an HSTS header.

`Dockerfile` (without suffix) is a copy of upstream's Dockerfile, kept as a reference for merging. It isn't built.

## Layout

| Path | Purpose |
| --- | --- |
| `Dockerfile.ng-php-base` | PHP-FPM base image with all required extensions |
| `Dockerfile.ng-v<major>` | Nextcloud image for one major version (`FROM` the PHP base image) |
| `rootfs/` | Config files and scripts copied into the image (nginx, PHP, s6, `run.sh`, `occ`, …) |
| `.github/workflows/` | Manually triggered build & push workflows |

## Update workflow

Upstream is checked out next to this repo as `../pk-wonderfall-nextcloud-dist-hoellen`.

1. **Pull upstream**: `git -C ../pk-wonderfall-nextcloud-dist-hoellen pull`
2. **Review changes**: check whether anything beyond version bumps and hashes changed, e.g.
   ```bash
   git -C ../pk-wonderfall-nextcloud-dist-hoellen log -p ORIG_HEAD..HEAD
   diff -r ../pk-wonderfall-nextcloud-dist-hoellen/rootfs rootfs
   ```
   Merge relevant changes (Dockerfile, `rootfs/`) manually.
3. **Update Dockerfiles**:
   - Patch release: update `NEXTCLOUD_VERSION` and `SHA256_SUM` in the existing `Dockerfile.ng-v<major>`.
   - New major: copy the previous `Dockerfile.ng-v<major>` to `Dockerfile.ng-v<new major>` and adjust
     versions (Nextcloud, PHP, Alpine, nginx, checksum).
   - New PHP/Alpine version: set the matching `PHP_VERSION`/`ALPINE_VERSION` in the Nextcloud
     Dockerfiles that should use it.
4. **Update the workflows**:
   - New PHP/Alpine version: add it to the matrix in `.github/workflows/build_nextcloud_php_base.yml`
     (and remove combinations no longer needed).
   - New major: bump the default `nc_major` in `.github/workflows/build_nextcloud_app.yml`.
5. **Commit & push**, then trigger the builds in GitHub → *Actions*:
   1. *Build Nextcloud PHP base image*, only if the PHP base changed.
      Builds every PHP/Alpine combination in the workflow matrix.
   2. *Build Nextcloud app image*, entering the major version (e.g. `31`).
      The full version tag is derived from `NEXTCLOUD_VERSION` in the Dockerfile.

Required repository secrets: `DOCKER_HUB_USERNAME` and `DOCKER_HUB_PASSWORD`
(use a Docker Hub [personal access token](https://docs.docker.com/security/for-developers/access-tokens/) with read/write scope, not the account password).
