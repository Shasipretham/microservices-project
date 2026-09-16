FROM python:3.10.8-slim@sha256:49749648f4426b31b20fca55ad854caa55ff59dc604f2f76b57d814e0a47c181 as base

FROM base as builder

# Fix: Debian 11 (bullseye) reached EOL on 2026-08-31.
# Point APT sources to the Debian snapshot archive so that
# package indexes and .deb files are consistent again.
RUN sed -i 's|deb.debian.org|snapshot.debian.org/archive/debian/20260825T000000Z|g' /etc/apt/sources.list \
    && sed -i 's|security.debian.org|snapshot.debian.org/archive/debian-security/20260825T000000Z|g' /etc/apt/sources.list \
    && echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/10-nocheckvalid \
    && apt-get -qq update \
    && apt-get install -y --no-install-recommends \
        wget g++ \
    && rm -rf /var/lib/apt/lists/*

# Download the grpc health probe
# renovate: datasource=github-releases depName=grpc-ecosystem/grpc-health-probe
ENV GRPC_HEALTH_PROBE_VERSION=v0.4.18
RUN wget -qO/bin/grpc_health_probe https://github.com/grpc-ecosystem/grpc-health-probe/releases/download/${GRPC_HEALTH_PROBE_VERSION}/grpc_health_probe-linux-amd64 && \
    chmod +x /bin/grpc_health_probe

# get packages
COPY requirements.txt .
RUN pip install -r requirements.txt

FROM base as without-grpc-health-probe-bin
# Enable unbuffered logging
ENV PYTHONUNBUFFERED=1
# Enable Profiler
ENV ENABLE_PROFILER=1

WORKDIR /email_server

# Grab packages from builder
COPY --from=builder /usr/local/lib/python3.10/ /usr/local/lib/python3.10/

# Add the application
COPY . .

EXPOSE 8080
ENTRYPOINT [ "python", "email_server.py" ]

FROM without-grpc-health-probe-bin

COPY --from=builder /bin/grpc_health_probe /bin/grpc_health_probe
