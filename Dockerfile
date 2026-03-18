# ─── Stage 1: build nfqws ────────────────────────────────────────────────────
FROM debian:bookworm-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        git \
        ca-certificates \
        libnetfilter-queue-dev \
        libcap-dev \
        libnfnetlink-dev \
        libmnl-dev \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth=1 https://github.com/bol-van/zapret.git /tmp/zapret \
    && cd /tmp/zapret/nfq  && make nfqws && strip nfqws \
    && cd /tmp/zapret/tpws && make tpws  && strip tpws \
    && git clone --depth=1 https://github.com/Flowseal/zapret-discord-youtube.git /tmp/zapret-lists

# ─── Stage 2: runtime ─────────────────────────────────────────────────────────
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        iptables \
        libnetfilter-queue1 \
        libcap2 \
        libnfnetlink0 \
        ipset \
        ffmpeg \
        curl \
        ca-certificates \
        python3 \
        python3-pip \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /tmp/zapret/nfq/nfqws  /usr/local/bin/nfqws
COPY --from=builder /tmp/zapret/tpws/tpws  /usr/local/bin/tpws
RUN chmod +x /usr/local/bin/nfqws /usr/local/bin/tpws

# Используем legacy-backend: nf_tables может отсутствовать в ядре хоста
RUN update-alternatives --set iptables  /usr/sbin/iptables-legacy \
    && update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

# ─── yt-dlp (via pip, works on all architectures) ─────────────────────────────
RUN pip3 install --no-cache-dir --break-system-packages yt-dlp

VOLUME ["/downloads"]

# ─── Assets from zapret-discord-youtube (cloned in builder) ──────────────────
COPY --from=builder /tmp/zapret-lists/bin/*.bin        /opt/zapret/bin/
COPY --from=builder /tmp/zapret-lists/lists/           /opt/zapret/lists/
COPY --from=builder /tmp/zapret-lists/.service/ipset-service.txt /opt/zapret/lists/ipset-all.txt

# Empty user-override lists (required so nfqws doesn't error on missing files)
RUN touch /opt/zapret/lists/list-general-user.txt \
          /opt/zapret/lists/list-exclude-user.txt \
          /opt/zapret/lists/ipset-exclude-user.txt

COPY entrypoint.sh /entrypoint.sh
COPY server.py     /app/server.py
RUN chmod +x /entrypoint.sh

ENV NFQUEUE_NUM=200
ENV TPWS_PORT=18080
ENV SERVER_PORT=8080

ENTRYPOINT ["/entrypoint.sh"]
