#!/usr/bin/env python3
"""
HTTP-сервер для скачивания видео через zapret DPI bypass.

GET /                          → HTML-форма
GET /download?url=<URL>        → скачать видео (mp4)
GET /download?url=<URL>&format=mp3  → скачать аудио (mp3)
"""

import glob
import http.server
import logging
import os
import socketserver
import subprocess
import tempfile
import urllib.parse
import uuid

TPWS_PORT   = int(os.environ.get("TPWS_PORT",   "1080"))
SERVER_PORT = int(os.environ.get("SERVER_PORT", "8080"))
COOKIES_FILE = os.environ.get("COOKIES_FILE", "/cookies.txt")

HTML = """\
<!DOCTYPE html>
<html lang="ru">
<head>
  <meta charset="utf-8">
  <title>Video Downloader</title>
  <style>
    body { font-family: sans-serif; max-width: 600px; margin: 60px auto; }
    input[type=text] { width: 100%; padding: 8px; font-size: 1em; box-sizing: border-box; }
    select, button { padding: 8px 16px; font-size: 1em; margin-top: 8px; }
    button { cursor: pointer; }
  </style>
</head>
<body>
  <h2>Video Downloader</h2>
  <form action="/download">
    <input type="text" name="url" placeholder="https://www.youtube.com/watch?v=..." required>
    <br>
    <select name="format">
      <option value="mp4">Видео (MP4)</option>
      <option value="mp3">Аудио (MP3)</option>
    </select>
    <button type="submit">Скачать</button>
  </form>
</body>
</html>
"""


class VideoHandler(http.server.BaseHTTPRequestHandler):

    def do_GET(self):
        req_id = uuid.uuid4().hex[:8]
        parsed = urllib.parse.urlparse(self.path)

        if parsed.path == "/":
            logging.info("[%s] [%s] GET /", req_id, self.client_address[0])
            body = HTML.encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        if parsed.path == "/download":
            params = urllib.parse.parse_qs(parsed.query)
            url = params.get("url", [None])[0]
            fmt = params.get("format", ["mp4"])[0]

            if not url:
                self.send_error(400, "Missing 'url' parameter")
                return

            self._download_and_send(req_id, url, fmt)
            return

        self.send_error(404)

    def _download_and_send(self, req_id: str, url: str, fmt: str):
        client = self.client_address[0]
        logging.info("[%s] [%s] request  url=%s format=%s", req_id, client, url, fmt)

        with tempfile.TemporaryDirectory() as tmpdir:
            cmd = [
                "yt-dlp",
                "--proxy", f"socks5://127.0.0.1:{TPWS_PORT}",
                "--output", f"{tmpdir}/%(title)s.%(ext)s",
                "--no-playlist",
                "--no-warnings",
            ]
            if os.path.isfile(COOKIES_FILE):
                cmd += ["--cookies", COOKIES_FILE]
                logging.info("[%s] [%s] using cookies file=%s", req_id, client, COOKIES_FILE)
            if fmt == "mp3":
                cmd += ["-x", "--audio-format", "mp3"]
            else:
                cmd += ["--merge-output-format", "mp4"]
            cmd.append(url)

            logging.info("[%s] [%s] downloading url=%s", req_id, client, url)
            result = subprocess.run(cmd)
            if result.returncode != 0:
                logging.error("[%s] [%s] download failed url=%s", req_id, client, url)
                self.send_error(500, "Download failed")
                return

            files = glob.glob(f"{tmpdir}/*")
            if not files:
                logging.error("[%s] [%s] no output file url=%s", req_id, client, url)
                self.send_error(500, "No output file produced")
                return

            filepath = files[0]
            filename  = os.path.basename(filepath)
            filesize  = os.path.getsize(filepath)
            mime      = "audio/mpeg" if fmt == "mp3" else "video/mp4"

            logging.info("[%s] [%s] sending   file=%s size=%d", req_id, client, filename, filesize)

            self.send_response(200)
            self.send_header("Content-Type", mime)
            self.send_header("Content-Length", str(filesize))
            encoded_filename = urllib.parse.quote(filename, encoding="utf-8")
            self.send_header(
                "Content-Disposition",
                f"attachment; filename*=UTF-8''{encoded_filename}",
            )
            self.end_headers()

            with open(filepath, "rb") as f:
                while chunk := f.read(1024 * 1024):
                    try:
                        self.wfile.write(chunk)
                    except (BrokenPipeError, ConnectionResetError):
                        logging.warning("[%s] [%s] connection lost during transfer file=%s", req_id, client, filename)
                        break

            logging.info("[%s] [%s] done      file=%s size=%d", req_id, client, filename, filesize)

        logging.info("[%s] [%s] deleted   file=%s", req_id, client, filename)

    def log_message(self, fmt, *args):
        pass  # отключаем стандартный лог BaseHTTPRequestHandler


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="[server] %(message)s")
    socketserver.ThreadingTCPServer.allow_reuse_address = True
    with socketserver.ThreadingTCPServer(("", SERVER_PORT), VideoHandler) as srv:
        logging.info("Listening on port %d", SERVER_PORT)
        srv.serve_forever()
