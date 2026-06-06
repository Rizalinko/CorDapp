# syntax=docker/dockerfile:1.7
# =============================================================================
# jar-image is the base layer containing the certified Java runtime and the verified Corda
#
# This layer contains ONLY a certified Java runtime plus the two verified Corda
# jars (the node runtime and the network bootstrapper). It changes only when the
# Corda version changes. node-image builds FROM this.
#
# Why a certified JRE base:
#   Corda 4.14 jars target Java 17 (class file version 61), so the runtime
#   base must be Java 17 or newer.
#   The base is eclipse-temurin:17-jre-jammy (Adoptium OpenJDK 17) because it
#   is widely mirrored, well-patched, and glibc-based on Docker Hub. For a
#   strictly "certified" prod build, swap JRE_IMAGE to azul/zulu-openjdk:17-jre.
#   Pin by digest (see PRODUCTION.md) in production for reproducibility.
#
# Why we download + checksum instead of COPYing a jar from context:
#   The jars are large (~110MB + ~170MB) and must never live in git. Fetching
#   from a pinned URL with a SHA-256 gate makes the build reproducible and
#   tamper-evident. Point CORDA_REPO_URL at an internal Nexus/Artifactory for
#   air-gapped builds.
# =============================================================================

ARG JRE_IMAGE=eclipse-temurin:17-jre-jammy

# stage 1: fetch + verify
# hadolint ignore=DL3006
FROM ${JRE_IMAGE} AS fetch
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG CORDA_VERSION=4.14
ARG CORDA_REPO_URL=https://repo1.maven.org/maven2/net/corda
# Pinned SHA-256 of the exact published artifacts (verified against Maven Central).
ARG CORDA_JAR_SHA256=8fd3ffa0bea08b7b6a17864ba01462bc175c9ac789973608e9186e01f11cc27a
ARG BOOTSTRAPPER_JAR_SHA256=36bbaf650810261b265dd1a91e6a7b6e2ff2c9c62efb8c510526bc5dff957b1a

# hadolint ignore=DL3008
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends curl ca-certificates; \
    rm -rf /var/lib/apt/lists/*; \
    mkdir -p /jars; \
    curl -fsSL "${CORDA_REPO_URL}/corda/${CORDA_VERSION}/corda-${CORDA_VERSION}.jar" -o /jars/corda.jar; \
    curl -fsSL "${CORDA_REPO_URL}/corda-tools-network-bootstrapper/${CORDA_VERSION}/corda-tools-network-bootstrapper-${CORDA_VERSION}.jar" -o /jars/corda-bootstrapper.jar; \
    echo "${CORDA_JAR_SHA256}  /jars/corda.jar"                 | sha256sum -c -; \
    echo "${BOOTSTRAPPER_JAR_SHA256}  /jars/corda-bootstrapper.jar" | sha256sum -c -

# stage 2: the published jar-image
# hadolint ignore=DL3006
FROM ${JRE_IMAGE} AS jar-image

ARG CORDA_VERSION=4.14
ENV CORDA_HOME=/opt/corda \
    CORDA_VERSION=${CORDA_VERSION}

LABEL org.opencontainers.image.title="corda-jar" \
      org.opencontainers.image.description="Certified JRE + verified Corda ${CORDA_VERSION} runtime and bootstrapper jars" \
      org.opencontainers.image.vendor="AcmeCorp" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.source="https://github.com/acmecorp/corda-platform"

COPY --from=fetch /jars/corda.jar             ${CORDA_HOME}/corda.jar
COPY --from=fetch /jars/corda-bootstrapper.jar ${CORDA_HOME}/corda-bootstrapper.jar

# Sanity check: the runtime jar is launchable in this JRE.
RUN java -jar ${CORDA_HOME}/corda.jar --version
