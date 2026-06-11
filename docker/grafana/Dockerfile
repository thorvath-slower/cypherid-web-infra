# Base pinned by multi-arch digest (bug-#012): immutable + verifiable. The
# digest is authoritative, so the previous ARG grafana_version (default 7.1.2)
# is dropped — bump the tag + digest together (Renovate does this) to change
# versions. ${BASE_REGISTRY} is the ECR pull-through forward hook.
ARG BASE_REGISTRY=
FROM ${BASE_REGISTRY}grafana/grafana:7.1.2@sha256:7558c103c5cac7bcab8eb4e7d0e18dd8b8bcae1f14ea5fe1eef066ec9241d5d5

COPY grafana.ini /etc/grafana/
USER root
ENV CHAMBER_VERSION=2.7.5
# bug-#012: corrected to the verified sha256 of chamber v2.7.5 linux-amd64
# (the previous value was stale/wrong AND never checked — see the RUN below).
ENV CHAMBER_SHA256SUM=acc9fa8bb3b9548a2494de82241767203a19082f61490b6f8e8c9e79cc1fbf2a
RUN apk add curl
RUN curl -Ls https://github.com/segmentio/chamber/releases/download/v${CHAMBER_VERSION}/chamber-v${CHAMBER_VERSION}-linux-amd64 > chamber-linux-amd64 && \
    echo "${CHAMBER_SHA256SUM}  chamber-linux-amd64" | sha256sum -c - && \
    chmod +x chamber-linux-amd64 && \
    mv chamber-linux-amd64 /usr/local/bin/chamber

USER grafana

ENTRYPOINT chamber exec $CHAMBER_NAMESPACE -- /run.sh
