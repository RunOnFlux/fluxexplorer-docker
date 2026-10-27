# Flux Insight Explorer image

`ghcr.io/runonflux/explorer`: the Flux block explorer (bitcore-node, insight-api and the
insight-ui React site, from the `@runonflux` npm packages) with its own fluxd. MongoDB runs as a
separate component (`mongo:8.0.34`).

Everything the explorer runs is in the image: Node 24, the npm packages pinned by
`package-lock.json`, fluxd from Flux's apt repository and its proving parameters. A container start
installs nothing, so a new image version is new code.

## Environment

| Variable | | Default |
|---|---|---|
| `DB_COMPONENT_NAME` | MongoDB host: on Flux, `flux<mongo component>_<app name>` | `fluxmongodb_explorerflux` |
| `BOOTSTRAP` | `1`: on a volume with no chain, stream the bootstrap archive into fluxd's datadir before the first start | off |
| `BOOTSTRAP_URL` | the archive | `https://cdn-geo.runonflux.io/apps/fluxshare/getfile/flux_explorer_bootstrap.tar.gz` |
| `TESTNET` | `1`: testnet | `0` |

## The volume

`/data/explorer` holds `bitcore-node.json` (written on every start from the environment), fluxd's
datadir `data/` and its `flux.conf` (written once, with a random RPC password). A volume from the
previous image keeps its chain: `/data/bitcore-node/bin/mynode/data` is moved to
`/data/explorer/data` on the first start.

The bootstrap streams into `tar` without a copy on disk. A failed attempt is discarded and retried,
three attempts in all; then fluxd syncs from its peers instead.

## Running

The entrypoint prepares `/data` as root and runs bitcore-node, and the fluxd it starts, as the
unprivileged `explorer` user. The health check passes when the API answers, or while the bootstrap
downloads or fluxd catches up, when fluxd answers. The container stops on `SIGINT`, which
bitcore-node handles by stopping fluxd cleanly.

## Releasing

A `v*` tag builds the image, pushes it by digest, runs `test/smoke.sh` on the pulled image and
only then tags it `ghcr.io/runonflux/explorer:<version>`. App specifications name a version tag.
