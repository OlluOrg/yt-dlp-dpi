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

```bash
# Video (MP4)
docker run --rm --network=host -v "${PWD}/downloads:/downloads" ghcr.io/olluorg/yt-dlp-dpi:latest "https://youtu.be/aqz-KE-bpKQ"

# Audio (MP3)
docker run --rm --network=host -v "${PWD}/downloads:/downloads" -e YT_DLP_OPTS="-x --audio-format mp3" ghcr.io/olluorg/yt-dlp-dpi:latest "https://youtu.be/aqz-KE-bpKQ"
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
| `TPWS_PORT` | `1080` | Internal SOCKS5 proxy port |
| `OUTPUT_DIR` | `/downloads` | Output directory for saved files |
| `YT_DLP_OPTS` | — | Extra yt-dlp flags |

## Requirements

- Docker
- Linux host or WSL2

## Based on

- [bol-van/zapret](https://github.com/bol-van/zapret)
- [Flowseal/zapret-discord-youtube](https://github.com/Flowseal/zapret-discord-youtube)
- [yt-dlp/yt-dlp](https://github.com/yt-dlp/yt-dlp)
