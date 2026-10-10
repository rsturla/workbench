# Build must use --skip-unused-stages=false for the chunkah/oci-archive stages.
# The build context must be the repository root so that FROM oci-archive:out.ociarchive
# resolves correctly (the -v mount writes the archive into the build context directory).
# See https://github.com/coreos/chunkah#splitting-an-image-at-build-time-buildahpodman-only

FROM scratch AS ctx

COPY ./scripts /scripts
COPY ./files /files

FROM quay.io/fedora/fedora-bootc:latest@sha256:38e6bbf7e1127d775482a62763c25d0f00fca392bb88176c2ae265ad8ccbc525 AS build

COPY --from=ctx files/ /

RUN --mount=type=cache,target=/var/cache \
    --mount=type=tmpfs,target=/var \
    --mount=type=tmpfs,target=/tmp \
    --mount=type=tmpfs,target=/run \
    --mount=type=bind,from=ctx,src=/scripts,dst=/buildcontext/scripts/ \
    bash /buildcontext/scripts/setup.sh && \
    bash /buildcontext/scripts/cleanup.sh

RUN --network=none \
    --mount=type=tmpfs,target=/run \
    bootc container lint --no-truncate --fatal-warnings

# Rechunk the image into component-aligned OCI layers via chunkah.
# Build must use --skip-unused-stages=false for the oci-archive stage to work.
# See https://github.com/coreos/chunkah#splitting-an-image-at-build-time-buildahpodman-only
FROM quay.io/coreos/chunkah:dev@sha256:5538de8ec5563b27ec2f382b6ecdd91cc0ebcd500cf7111cf09ea408b6722384 AS chunkah
RUN --mount=from=build,src=/,target=/chunkah,ro \
  chunkah build \
  --prune /sysroot/ \
  --max-layers 128 \
  > /run/src/out.ociarchive

FROM oci-archive:out.ociarchive

LABEL containers.bootc=1
LABEL ostree.bootable=true
