# syntax=docker/dockerfile:1
ARG BASE_IMAGE=ubuntu:26.04
FROM ${BASE_IMAGE} AS runtime
# Optional combined CA bundle for managed build environments; never retained.
RUN --mount=type=secret,id=proxy_ca \
    set -eu; \
    if [ -f /run/secrets/proxy_ca ]; then \
      export SSL_CERT_FILE=/run/secrets/proxy_ca; \
      printf 'Acquire::https::CaInfo "/run/secrets/proxy_ca";\n' > /etc/apt/apt.conf.d/99proxy-ca; \
    fi; \
    apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates csh libgfortran5 libgomp1 libblas3 liblapack3 procps \
    && rm -rf /var/lib/apt/lists/* /etc/apt/apt.conf.d/99proxy-ca
COPY docker/entrypoint.sh /usr/local/bin/gamess-job
RUN chmod 0755 /usr/local/bin/gamess-job && mkdir -p /work /scratch /opt/gamess
ENV HOME=/tmp OMP_NUM_THREADS=1
WORKDIR /work
USER 1000:1000
ENTRYPOINT ["/usr/local/bin/gamess-job"]
CMD ["--help"]

FROM runtime AS packaged
USER root
# A locally prepared, licensed installation; not a source archive.
COPY vendor/gamess/ /opt/gamess/
RUN test -x /opt/gamess/rungms
USER 1000:1000
