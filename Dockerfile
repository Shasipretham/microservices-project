FROM python:3.10.8-slim@sha256:49749648f4426b31b20fca55ad854caa55ff59dc604f2f76b57d814e0a47c181 as base

FROM base as builder

# Debian 11 (bullseye) LTS reached EOL on 2026-08-31.
# deb.debian.org's security pool is now broken (index exists, .deb files removed).
# Fix: completely rewrite sources.list to use the frozen snapshot.debian.org archive.
# NOTE: Do NOT append /debian after the timestamp — that creates an invalid URL.
RUN cat > /etc/apt/sources.list <<'EOF'
deb http://snapshot.debian.org/archive/debian/20260825T000000Z bullseye main
deb http://snapshot.debian.org/archive/debian/20260825T000000Z bullseye-updates main
deb http://snapshot.debian.org/archive/debian-security/20260825T000000Z bullseye-security main
EOF

RUN echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/10-nocheckvalid \
    && apt-get -qq update \
    && apt-get install -y --no-install-recommends \
        wget g++ \
    && rm -rf /var/lib/apt/lists/*

# Download the grpc health probe
# renovate: datasource=github-releases depName=grpc-ecosystem/grpc-health-probe
ENV GRPC_HEALTH_PROBE_VERSION=v0.4.18
RUN wget -qO/bin/grpc_health_probe https://github.com/grpc-ecosystem/grpc-health-probe/releases/download/${GRPC_HEALTH_PROBE_VERSION}/grpc_health_probe-linux-amd64 && \
    chmod +x /bin/grpc_health_probe

# Get Python dependencies
COPY requirements.txt .
RUN pip install -r requirements.txt

FROM base as without-grpc-health-probe-bin
# Enable unbuffered logging
ENV PYTHONUNBUFFERED=1
# Enable Profiler
ENV ENABLE_PROFILER=1

WORKDIR /recommendationservice

# Grab packages from builder
COPY --from=builder /usr/local/lib/python3.10/ /usr/local/lib/python3.10/

# Add the application
COPY . .

EXPOSE 8080
ENTRYPOINT [ "python", "recommendation_server.py" ]

FROM without-grpc-health-probe-bin

COPY --from=builder /bin/grpc_health_probe /bin/grpc_health_probe
