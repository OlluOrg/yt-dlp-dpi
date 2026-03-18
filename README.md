# YouTube Downloader (Docker)

Инструмент для скачивания видео и аудио с YouTube из России.

Внутри работает [yt-dlp](https://github.com/yt-dlp/yt-dlp) в связке с [zapret/tpws](https://github.com/bol-van/zapret) для стабильного соединения с серверами YouTube.

## Использование

### Веб-интерфейс

```bash
docker compose up
```

Открыть в браузере: `http://localhost:8080`

Вставить ссылку, выбрать формат — файл скачается напрямую в браузер.

### Командная строка

```bash
# Видео (MP4)
docker run --rm --network=host -v "${PWD}/downloads:/downloads" ghcr.io/olluorg/yt-dlp-dpi:latest "https://www.youtube.com/watch?v=..."

# Аудио (MP3)
docker run --rm --network=host -v "${PWD}/downloads:/downloads" -e YT_DLP_OPTS="-x --audio-format mp3" ghcr.io/olluorg/yt-dlp-dpi:latest "https://www.youtube.com/watch?v=..."
```

Файлы сохраняются в папку `./downloads/`.

## Готовый образ

```bash
docker pull ghcr.io/olluorg/yt-dlp-dpi:latest
```

Образ автоматически пересобирается при каждом обновлении репозитория.

## Сборка вручную

```bash
docker build -t yt-dlp-dpi .
```

Всё необходимое скачивается автоматически во время сборки.

## REST API

### `GET /`
Веб-форма для скачивания через браузер.

---

### `GET /download`

Скачивает видео или аудио и отдаёт файл напрямую в ответе.

**Параметры запроса:**

| Параметр | Обязательный | Значения | По умолчанию | Описание |
|---|---|---|---|---|
| `url` | да | любая ссылка yt-dlp | — | Ссылка на видео |
| `format` | нет | `mp4`, `mp3` | `mp4` | Формат файла |

**Примеры:**

```
GET /download?url=https://www.youtube.com/watch?v=...
GET /download?url=https://www.youtube.com/watch?v=...&format=mp3
```

**Ответы:**

| Код | Описание |
|---|---|
| `200` | Файл в теле ответа (`Content-Disposition: attachment`) |
| `400` | Не передан параметр `url` |
| `500` | Ошибка скачивания |

**Заголовки ответа при успехе:**
```
Content-Type: video/mp4  |  audio/mpeg
Content-Disposition: attachment; filename="<название видео>.<ext>"
Content-Length: <размер в байтах>
```

## Переменные окружения

| Переменная | По умолчанию | Описание |
|---|---|---|
| `SERVER_PORT` | `8080` | Порт веб-интерфейса |
| `TPWS_PORT` | `1080` | Порт внутреннего SOCKS5-прокси |
| `OUTPUT_DIR` | `/downloads` | Папка для сохранения файлов |
| `YT_DLP_OPTS` | — | Дополнительные флаги yt-dlp |

## Требования

- Docker
- Linux-хост или WSL2

## Основано на

- [bol-van/zapret](https://github.com/bol-van/zapret)
- [Flowseal/zapret-discord-youtube](https://github.com/Flowseal/zapret-discord-youtube)
- [yt-dlp/yt-dlp](https://github.com/yt-dlp/yt-dlp)
