# Base pinned by multi-arch digest (bug-#012); ${BASE_REGISTRY} is the ECR
# pull-through forward hook (empty default = Docker Hub).
ARG BASE_REGISTRY=
FROM ${BASE_REGISTRY}python:3.12-slim-bookworm@sha256:8a7e7cc04fd3e2bd787f7f24e22d5d119aa590d429b50c95dfe12b3abe52f48b

# pip routing hook (non-secret): proxy index when supplied, public otherwise.
ARG PIP_INDEX_URL=https://pypi.org/simple/

RUN mkdir -p /app
WORKDIR /app

COPY requirements.txt ./
RUN pip config set global.index-url "$PIP_INDEX_URL" \
 && pip install -r requirements.txt

COPY s3_tar_writer/s3_tar_writer.py ./
