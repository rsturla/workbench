# Build must use --skip-unused-stages=false for the chunkah/oci-archive stages.
# The build context must be the repository root so that FROM oci-archive:out.ociarchive
# resolves correctly (the -v mount writes the archive into the build context directory).
# See https://github.com/coreos/chunkah#splitting-an-image-at-build-time-buildahpodman-only

FROM scratch AS ctx

COPY ./scripts /scripts
COPY ./files /files

FROM quay.io/fedora/fedora-bootc:latest@sha256:3d28554659f56aea45638c6da31d95dcfd09c4028b12de6b9de7e40ea831cda0 AS build

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
FROM quay.io/coreos/chunkah:dev@sha256:51cd01ce6f04f129b7049262905551fbeb8d0277228b3520bb90a239021157b4 AS chunkah
RUN --mount=from=build,src=/,target=/chunkah,ro \
  chunkah build \
  --prune /sysroot/ \
  --max-layers 128 \
  > /run/src/out.ociarchive

FROM oci-archive:out.ociarchive

LABEL containers.bootc=1
LABEL ostree.bootable=true
