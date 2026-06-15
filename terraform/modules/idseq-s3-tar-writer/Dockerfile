# Base pinned by multi-arch digest (bug-#012); ${BASE_REGISTRY} is the ECR
# pull-through forward hook (empty default = Docker Hub).
ARG BASE_REGISTRY=
FROM ${BASE_REGISTRY}python:3.7-slim-bookworm@sha256:b53f496ca43e5af6994f8e316cf03af31050bf7944e0e4a308ad86c001cf028b

# pip routing hook (non-secret): proxy index when supplied, public otherwise.
ARG PIP_INDEX_URL=https://pypi.org/simple/

RUN mkdir -p /app
WORKDIR /app

COPY requirements.txt ./
RUN pip config set global.index-url "$PIP_INDEX_URL" \
 && pip install -r requirements.txt

COPY s3_tar_writer/s3_tar_writer.py ./
