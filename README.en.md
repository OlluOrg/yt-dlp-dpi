# YouTube Downloader (Docker)

A tool for downloading videos and audio from YouTube.

Powered by [yt-dlp](https://github.com/yt-dlp/yt-dlp) combined with [zapret/tpws](https://github.com/bol-van/zapret) for stable connectivity to YouTube servers.

[Русская версия →](README.md)

## Usage

### Web interface

```bash
docker compose up
```

Open in browser: `http://localhost:8080`

Paste a link, choose a format — the file will download directly in the browser.

### Command line

**Linux / Raspberry Pi:**
```bash
# Video (MP4)
docker run --rm --network=host -v "${PWD}/downloads:/downloads" ghcr.io/olluorg/yt-dlp-dpi:latest "https://youtu.be/aqz-KE-bpKQ"

# Audio (MP3)
docker run --rm --network=host -v "${PWD}/downloads:/downloads" -e YT_DLP_OPTS="-x --audio-format mp3" ghcr.io/olluorg/yt-dlp-dpi:latest "https://youtu.be/aqz-KE-bpKQ"
```

**Windows (WSL2):**
```bash
docker run --rm --network=host -v "${PWD}/downloads:/downloads" ghcr.io/olluorg/yt-dlp-dpi:latest "https://youtu.be/aqz-KE-bpKQ"
```

**macOS:**
```bash
# No DPI bypass needed on macOS — disable TPWS_OPTS
docker run --rm --network=host -v "${PWD}/downloads:/downloads" -e TPWS_OPTS="" ghcr.io/olluorg/yt-dlp-dpi:latest "https://youtu.be/aqz-KE-bpKQ"
```

Files are saved to the `./downloads/` folder.

## Pre-built image

```bash
docker pull ghcr.io/olluorg/yt-dlp-dpi:latest
```

The image is automatically rebuilt on every repository update.

## Manual build

```bash
docker build -t yt-dlp-dpi .
```

Everything required is downloaded automatically during the build.

## REST API

### `GET /`
Web form for downloading via browser.

---

### `GET /download`

Downloads video or audio and returns the file directly in the response.

**Query parameters:**

| Parameter | Required | Values | Default | Description |
|---|---|---|---|---|
| `url` | yes | any yt-dlp supported URL | — | Video URL |
| `format` | no | `mp4`, `mp3` | `mp4` | Output format |

**Examples:**

```
GET /download?url=https://youtu.be/aqz-KE-bpKQ
GET /download?url=https://youtu.be/aqz-KE-bpKQ&format=mp3
```

**Responses:**

| Code | Description |
|---|---|
| `200` | File in response body (`Content-Disposition: attachment`) |
| `400` | Missing `url` parameter |
| `500` | Download failed |

**Response headers on success:**
```
Content-Type: video/mp4  |  audio/mpeg
Content-Disposition: attachment; filename="<video title>.<ext>"
Content-Length: <size in bytes>
```

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `SERVER_PORT` | `8080` | Web interface port |
| `TPWS_PORT` | `18080` | Internal SOCKS5 proxy port |
| `TPWS_OPTS` | `--split-pos=1 --oob=tls` | DPI bypass options. For macOS/servers outside Russia: `""` |
| `OUTPUT_DIR` | `/downloads` | Output directory for saved files |
| `COOKIES_FILE` | `/cookies.txt` | Path to cookies file inside the container |
| `YT_DLP_OPTS` | — | Extra yt-dlp flags |

## Cookies (bot check bypass)

YouTube may require authentication. Export cookies from your browser and pass them to the container:

1. Install the [Get cookies.txt LOCALLY](https://chromewebstore.google.com/detail/get-cookiestxt-locally/cclelndahbckbenkjhflpdbgdldlbecc) extension for Chrome or [cookies.txt](https://addons.mozilla.org/en-US/firefox/addon/cookies-txt/) for Firefox
2. Open youtube.com and sign in
3. Export cookies to a `cookies.txt` file
4. Pass the file when running:

```bash
# Command line
docker run --rm --network=host -v "${PWD}/downloads:/downloads" -v "${PWD}/cookies.txt:/cookies.txt:ro" ghcr.io/olluorg/yt-dlp-dpi:latest "https://youtu.be/aqz-KE-bpKQ"
```

For the web interface, add to `docker-compose.yml`:
```yaml
volumes:
  - ./cookies.txt:/cookies.txt:ro
```

## Requirements

- Docker
- Linux host or WSL2

## Based on

- [bol-van/zapret](https://github.com/bol-van/zapret)
- [Flowseal/zapret-discord-youtube](https://github.com/Flowseal/zapret-discord-youtube)
- [yt-dlp/yt-dlp](https://github.com/yt-dlp/yt-dlp)
