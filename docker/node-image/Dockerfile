# The runtime image for a Corda node.
#
# Builds FROM jar-image (certified JRE + verified Corda jars).
# The follwowing are added on top:
#   * a non-root 'corda' user and group, with a fixed UID/GID (1000) for ease of use in dev and prod.
#   * the entrypoint + config generator + healthcheck
#   * the PostgreSQL JDBC driver in drivers/ (Corda does not bundle one)
#   * a place for CorDapps (baked in at build time OR mounted at runtime)
#
# The same image runs the node (default) and the network bootstrapper (via the
# 'bootstrap' entrypoint mode), so the whole platform ships as two images.
# =============================================================================

# JAR_IMAGE controls where the certified JRE + Corda jars come from.
#
#   Registry (default):
#     docker build docker/node-image
#
#   Local jar-image:
#     docker build -t corda-jar:local docker/jar-image
#     docker build --build-arg JAR_IMAGE=corda-jar:local docker/node-image
ARG JAR_IMAGE=ghcr.io/acmecorp/corda-jar:4.14

# stage 1: fetch the JDBC driver
# hadolint ignore=DL3006
FROM ${JAR_IMAGE} AS drivers
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ARG POSTGRES_JDBC_VERSION=42.7.4
ARG POSTGRES_JDBC_SHA256=188976721ead8e8627eb6d8389d500dccc0c9bebd885268a3047180274a6031e
# hadolint ignore=DL3008
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends curl ca-certificates; \
    rm -rf /var/lib/apt/lists/*; \
    mkdir -p /drivers; \
    curl -fsSL "https://repo1.maven.org/maven2/org/postgresql/postgresql/${POSTGRES_JDBC_VERSION}/postgresql-${POSTGRES_JDBC_VERSION}.jar" \
        -o /drivers/postgresql.jar; \
    echo "${POSTGRES_JDBC_SHA256}  /drivers/postgresql.jar" | sha256sum -c -

# stage 2: the runtime node-image
# hadolint ignore=DL3006
FROM ${JAR_IMAGE} AS node-image
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG CORDA_USER=corda
ARG CORDA_UID=1000
ARG CORDA_GID=1000

# CORDA_HOME    immutable distribution: jars, bin, drivers, baked CorDapps.
# CORDA_BASE_DIR mutable node base directory (a volume/PVC mounts here): certs,
#               persistence, cordapps, network-parameters, node.conf, logs.
# Keeping them separate means a mount never shadows the jars/scripts.
ENV CORDA_HOME=/opt/corda \
    CORDA_BASE_DIR=/var/lib/corda \
    CAPSULE_CACHE_DIR=/var/lib/corda/.capsule \
    JAVA_OPTS="-Xmx512m -XX:+UseG1GC" \
    NODE_ROLE=node \
    P2P_PORT=10200 \
    RPC_PORT=10201 \
    RPC_ADMIN_PORT=10202 \
    PATH="/opt/corda/bin:${PATH}"

# Non-root user + the two trees.
RUN set -eux; \
    groupadd -g "${CORDA_GID}" "${CORDA_USER}"; \
    useradd -l -u "${CORDA_UID}" -g "${CORDA_GID}" -d /var/lib/corda -s /usr/sbin/nologin "${CORDA_USER}"; \
    mkdir -p /opt/corda/{bin,drivers,cordapps-baked}; \
    mkdir -p /var/lib/corda/{cordapps,certificates,persistence,logs,additional-node-infos,.capsule}; \
    chown -R "${CORDA_UID}:${CORDA_GID}" /opt/corda /var/lib/corda

COPY --chown=${CORDA_UID}:${CORDA_GID} --from=drivers /drivers/postgresql.jar /opt/corda/drivers/postgresql.jar
COPY --chown=${CORDA_UID}:${CORDA_GID} scripts/ /opt/corda/bin/

# CorDapps: the base image ships an empty cordapps-baked/. The Part 4 artifact
# image layers jars into it; dev mounts them into the base dir's cordapps/.

RUN chmod +x /opt/corda/bin/*.sh

USER ${CORDA_UID}
WORKDIR /var/lib/corda

# P2P (inter-node), RPC (clients), RPC admin
EXPOSE 10200 10201 10202

# The whole node base directory is the persistent volume/PVC.
VOLUME ["/var/lib/corda"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=180s --retries=5 \
    CMD ["/opt/corda/bin/healthcheck.sh"]

ENTRYPOINT ["/opt/corda/bin/entrypoint.sh"]
CMD ["node"]
