#!/bin/bash
# entrypoint.sh — zapret DPI bypass + опциональное скачивание через yt-dlp
#
# Стратегия bypass (два уровня, оба из general.bat):
#
#   1. tpws SOCKS5  — всегда работает, userspace, kernel-модули не нужны.
#                     tpws слушает на 127.0.0.1:TPWS_PORT, yt-dlp идёт через него.
#
#   2. nfqws NFQUEUE — перехватывает ВЕСЬ трафик (TCP+UDP), включая Discord/QUIC.
#                      Требует --privileged (для загрузки xt_NFQUEUE).
#                      Включается автоматически если модуль доступен.
#
# Режимы запуска:
#   Без аргументов     → daemon: tpws (+ nfqws если --privileged) в foreground
#   С URL/аргументами  → download: tpws в фоне → yt-dlp --proxy socks5://... → выход
#
# Переменные окружения:
#   TPWS_PORT    — порт SOCKS5 прокси tpws       (default: 1080)
#   NFQUEUE_NUM  — номер очереди NFQUEUE          (default: 200)
#   YT_DLP_OPTS  — доп. флаги yt-dlp
#   OUTPUT_DIR   — куда сохранять файлы           (default: /downloads)

set -euo pipefail

TPWS_PORT="${TPWS_PORT:-1080}"
QNUM="${NFQUEUE_NUM:-200}"
BIN=/opt/zapret/bin
LISTS=/opt/zapret/lists
OUTPUT_DIR="${OUTPUT_DIR:-/downloads}"

TPWS_PID=""
NFQWS_PID=""

# ─── Cleanup ──────────────────────────────────────────────────────────────────

cleanup() {
    [[ -n "$TPWS_PID"  ]] && kill "$TPWS_PID"  2>/dev/null || true
    [[ -n "$NFQWS_PID" ]] && kill "$NFQWS_PID" 2>/dev/null || true
    del_nfqueue_rules iptables  2>/dev/null || true
    del_nfqueue_rules ip6tables 2>/dev/null || true
    echo "[zapret] Stopped."
}
trap cleanup EXIT INT TERM

# ─── tpws SOCKS5 (стратегия TCP из general.bat) ───────────────────────────────
# tpws работает в userspace как SOCKS5-прокси — kernel-модули не нужны.
# Применяет DPI desync к TCP-соединениям, проходящим через прокси.

run_tpws() {
    # tpws синтаксис: --split-pos, --disorder, --tlsrec, --oob
    # (не --dpi-desync — это только nfqws)
    tpws \
        --port="$TPWS_PORT" \
        --socks \
        --bind-addr=127.0.0.1 \
        --split-pos=1 \
        --oob=tls
}

# ─── nfqws NFQUEUE (полная стратегия general.bat, TCP+UDP) ───────────────────
# Требует --privileged и xt_NFQUEUE в ядре.

add_nfqueue_rules() {
    local ipt="$1"
    $ipt -t mangle -A OUTPUT  -p tcp -m multiport --dports 80,443,2053,2083,2087,2096,8443 \
         -j NFQUEUE --queue-num "$QNUM" --queue-bypass
    $ipt -t mangle -A FORWARD -p tcp -m multiport --dports 80,443,2053,2083,2087,2096,8443 \
         -j NFQUEUE --queue-num "$QNUM" --queue-bypass
    $ipt -t mangle -A OUTPUT  -p udp -m multiport --dports 443,19294:19344,50000:50100 \
         -j NFQUEUE --queue-num "$QNUM" --queue-bypass
    $ipt -t mangle -A FORWARD -p udp -m multiport --dports 443,19294:19344,50000:50100 \
         -j NFQUEUE --queue-num "$QNUM" --queue-bypass
}

del_nfqueue_rules() {
    local ipt="$1"
    $ipt -t mangle -S OUTPUT  2>/dev/null | grep "queue-num $QNUM" | \
        sed 's/^-A/-D/' | while read -r rule; do $ipt -t mangle $rule 2>/dev/null || true; done
    $ipt -t mangle -S FORWARD 2>/dev/null | grep "queue-num $QNUM" | \
        sed 's/^-A/-D/' | while read -r rule; do $ipt -t mangle $rule 2>/dev/null || true; done
}

run_nfqws() {
    nfqws \
        --qnum="$QNUM" \
        \
        --filter-udp=443 \
            --hostlist="$LISTS/list-general.txt" \
            --hostlist="$LISTS/list-general-user.txt" \
            --hostlist-exclude="$LISTS/list-exclude.txt" \
            --hostlist-exclude="$LISTS/list-exclude-user.txt" \
            --ipset-exclude="$LISTS/ipset-exclude.txt" \
            --ipset-exclude="$LISTS/ipset-exclude-user.txt" \
            --dpi-desync=fake \
            --dpi-desync-repeats=6 \
            --dpi-desync-fake-quic="$BIN/quic_initial_www_google_com.bin" \
        --new \
        \
        --filter-udp=19294-19344,50000-50100 \
            --filter-l7=discord,stun \
            --dpi-desync=fake \
            --dpi-desync-repeats=6 \
        --new \
        \
        --filter-tcp=2053,2083,2087,2096,8443 \
            --hostlist-domains=discord.media \
            --dpi-desync=multisplit \
            --dpi-desync-split-seqovl=681 \
            --dpi-desync-split-pos=1 \
            --dpi-desync-split-seqovl-pattern="$BIN/tls_clienthello_www_google_com.bin" \
        --new \
        \
        --filter-tcp=443 \
            --hostlist="$LISTS/list-google.txt" \
            --dpi-desync=multisplit \
            --dpi-desync-split-seqovl=681 \
            --dpi-desync-split-pos=1 \
            --dpi-desync-split-seqovl-pattern="$BIN/tls_clienthello_www_google_com.bin" \
        --new \
        \
        --filter-tcp=80,443 \
            --hostlist="$LISTS/list-general.txt" \
            --hostlist="$LISTS/list-general-user.txt" \
            --hostlist-exclude="$LISTS/list-exclude.txt" \
            --hostlist-exclude="$LISTS/list-exclude-user.txt" \
            --ipset-exclude="$LISTS/ipset-exclude.txt" \
            --ipset-exclude="$LISTS/ipset-exclude-user.txt" \
            --dpi-desync=multisplit \
            --dpi-desync-split-seqovl=568 \
            --dpi-desync-split-pos=1 \
            --dpi-desync-split-seqovl-pattern="$BIN/tls_clienthello_4pda_to.bin" \
        --new \
        \
        --filter-udp=443 \
            --ipset="$LISTS/ipset-all.txt" \
            --hostlist-exclude="$LISTS/list-exclude.txt" \
            --hostlist-exclude="$LISTS/list-exclude-user.txt" \
            --ipset-exclude="$LISTS/ipset-exclude.txt" \
            --ipset-exclude="$LISTS/ipset-exclude-user.txt" \
            --dpi-desync=fake \
            --dpi-desync-repeats=6 \
            --dpi-desync-fake-quic="$BIN/quic_initial_www_google_com.bin" \
        --new \
        \
        --filter-tcp=80,443,8443 \
            --ipset="$LISTS/ipset-all.txt" \
            --hostlist-exclude="$LISTS/list-exclude.txt" \
            --hostlist-exclude="$LISTS/list-exclude-user.txt" \
            --ipset-exclude="$LISTS/ipset-exclude.txt" \
            --ipset-exclude="$LISTS/ipset-exclude-user.txt" \
            --dpi-desync=multisplit \
            --dpi-desync-split-seqovl=568 \
            --dpi-desync-split-pos=1 \
            --dpi-desync-split-seqovl-pattern="$BIN/tls_clienthello_4pda_to.bin"
}

# ─── Запуск tpws ─────────────────────────────────────────────────────────────

echo "[zapret] Starting tpws SOCKS5 on 127.0.0.1:${TPWS_PORT}..."
run_tpws &
TPWS_PID=$!

# Ждём пока порт реально займётся (до 5 секунд)
TPWS_READY=0
for i in $(seq 1 10); do
    sleep 0.5
    if ! kill -0 "$TPWS_PID" 2>/dev/null; then
        echo "[zapret] ERROR: tpws exited (port ${TPWS_PORT} may be already in use)" >&2
        echo "[zapret] Try setting a different TPWS_PORT, e.g.: -e TPWS_PORT=18080" >&2
        exit 1
    fi
    if ss -tlnp 2>/dev/null | grep -q ":${TPWS_PORT}"; then
        TPWS_READY=1
        break
    fi
done

if [[ $TPWS_READY -eq 0 ]]; then
    echo "[zapret] ERROR: tpws did not bind to port ${TPWS_PORT} within 5 seconds" >&2
    exit 1
fi
echo "[zapret] tpws running (pid=$TPWS_PID, port=$TPWS_PORT)"

# ─── Попытка запустить nfqws (опционально, нужен --privileged) ────────────────

NFQUEUE_ACTIVE=0
if modprobe xt_NFQUEUE 2>/dev/null || grep -qw xt_NFQUEUE /proc/modules 2>/dev/null; then
    echo "[zapret] xt_NFQUEUE available, setting up iptables..."
    if add_nfqueue_rules iptables 2>/dev/null; then
        add_nfqueue_rules ip6tables 2>/dev/null || true
        run_nfqws &
        NFQWS_PID=$!
        sleep 0.5
        if kill -0 "$NFQWS_PID" 2>/dev/null; then
            NFQUEUE_ACTIVE=1
            echo "[zapret] nfqws running (pid=$NFQWS_PID) — full bypass active (TCP+UDP)."
        else
            echo "[zapret] WARNING: nfqws exited early." >&2
            del_nfqueue_rules iptables 2>/dev/null || true
        fi
    else
        echo "[zapret] WARNING: iptables setup failed." >&2
    fi
else
    echo "[zapret] xt_NFQUEUE unavailable — using tpws SOCKS5 only (TCP bypass)."
    echo "[zapret]   → Add --privileged for full TCP+UDP bypass via nfqws."
fi

# ─── Mode selection ───────────────────────────────────────────────────────────

if [[ $# -eq 0 ]]; then
    # ── Daemon mode: HTTP-сервер ──────────────────────────────────────────────
    echo "[zapret] Daemon mode. HTTP server: http://0.0.0.0:${SERVER_PORT:-8080}"
    exec python3 /app/server.py
else
    # ── Download mode ─────────────────────────────────────────────────────────
    mkdir -p "$OUTPUT_DIR"
    echo "[yt-dlp] Downloading: $*"
    echo "[yt-dlp] Output dir:  $OUTPUT_DIR"
    echo "[yt-dlp] DPI bypass:  socks5://127.0.0.1:${TPWS_PORT}$(
        [[ $NFQUEUE_ACTIVE -eq 1 ]] && echo " + nfqws (NFQUEUE)" || echo " (tpws only)"
    )"

    # shellcheck disable=SC2086
    yt-dlp \
        --proxy "socks5://127.0.0.1:${TPWS_PORT}" \
        --output "$OUTPUT_DIR/%(title)s.%(ext)s" \
        --merge-output-format mp4 \
        --no-playlist \
        ${YT_DLP_OPTS:-} \
        "$@"

    echo "[yt-dlp] Done. Files saved to $OUTPUT_DIR"
fi
