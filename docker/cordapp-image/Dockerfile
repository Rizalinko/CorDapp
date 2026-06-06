# syntax=docker/dockerfile:1.7
# CorDapp artifact image.
#
# Layers CorDapp JARs on top of the corda-node runtime. Same layering pattern
# as jar-image -> node-image: a rarely changing base layer (the Corda runtime)
# and a frequently changing application layer (the CorDapp JARs).
#
# Build locally (place JARs in docker/cordapp-image/cordapps/ first):
#   docker build \
#     --build-arg NODE_IMAGE=ghcr.io/acmecorp/corda-node:4.14.0 \
#     --build-arg CORDAPP_VERSION=1.0.0 \
#     -t ghcr.io/acmecorp/corda-node:4.14.0-cordapp-1.0.0 \
#     docker/cordapp-image
#
# In CI the JAR is downloaded before docker build (see .github/workflows/cordapp.yml).

ARG NODE_IMAGE=ghcr.io/acmecorp/corda-node:4.14.0
ARG CORDAPP_VERSION=dev

# hadolint ignore=DL3006
FROM ${NODE_IMAGE}

ARG CORDAPP_VERSION

LABEL org.opencontainers.image.title="corda-node+cordapp" \
      org.opencontainers.image.description="Corda node runtime with CorDapp jars baked in" \
      org.opencontainers.image.vendor="AcmeCorp" \
      org.opencontainers.image.source="https://github.com/acmecorp/corda-platform" \
      com.acmecorp.cordapp.version="${CORDAPP_VERSION}"

# JARs are placed in cordapps/ by CI (cordapp.yml) or by the developer locally.
# Fails at build time if no JAR is present, preventing an empty artifact image.
COPY --chown=1000:1000 cordapps/*.jar /opt/corda/cordapps-baked/
