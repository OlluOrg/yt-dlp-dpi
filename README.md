# YouTube Downloader (Docker)

Инструмент для скачивания видео и аудио с YouTube из России.

Внутри работает [yt-dlp](https://github.com/yt-dlp/yt-dlp) в связке с [zapret/tpws](https://github.com/bol-van/zapret) для стабильного соединения с серверами YouTube.

[English version →](README.en.md)

## Использование

### Веб-интерфейс

```bash
docker compose up
```

Открыть в браузере: `http://localhost:8080`

Вставить ссылку, выбрать формат — файл скачается напрямую в браузер.

### Командная строка

**Linux / Raspberry Pi:**
```bash
# Видео (MP4)
docker run --rm --network=host -v "${PWD}/downloads:/downloads" ghcr.io/olluorg/yt-dlp-dpi:latest "https://youtu.be/aqz-KE-bpKQ"

# Аудио (MP3)
docker run --rm --network=host -v "${PWD}/downloads:/downloads" -e YT_DLP_OPTS="-x --audio-format mp3" ghcr.io/olluorg/yt-dlp-dpi:latest "https://youtu.be/aqz-KE-bpKQ"
```

**Windows (WSL2):**
```bash
docker run --rm --network=host -v "${PWD}/downloads:/downloads" ghcr.io/olluorg/yt-dlp-dpi:latest "https://youtu.be/aqz-KE-bpKQ"
```

**macOS:**
```bash
# На macOS не нужен DPI bypass — отключаем TPWS_OPTS
docker run --rm --network=host -v "${PWD}/downloads:/downloads" -e TPWS_OPTS="" ghcr.io/olluorg/yt-dlp-dpi:latest "https://youtu.be/aqz-KE-bpKQ"
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

### `GET /info`

Возвращает метаданные видео без скачивания.

**Параметры:** `url` (обязательный)

**Пример:** `GET /info?url=https://youtu.be/aqz-KE-bpKQ`

**Ответ `200`:**
```json
{
  "title": "Rick Astley - Never Gonna Give You Up",
  "duration": 213,
  "uploader": "Rick Astley",
  "thumbnail": "https://..."
}
```

---

### `GET /search`

Ищет видео на YouTube и возвращает первый результат.

**Параметры:** `query` (обязательный)

**Пример:** `GET /search?query=never+gonna+give+you+up`

**Ответ `200`:**
```json
{
  "url": "https://www.youtube.com/watch?v=aqz-KE-bpKQ",
  "title": "Rick Astley - Never Gonna Give You Up",
  "duration": 213,
  "uploader": "Rick Astley"
}
```

---

### `GET /download`

Скачивает видео или аудио и отдаёт файл напрямую в ответе.

**Параметры запроса:**

| Параметр | Обязательный | Значения | По умолчанию | Описание |
|---|---|---|---|---|
| `url` | да | любая ссылка yt-dlp | — | Ссылка на видео |
| `format` | нет | `mp4`, `mp3` | `mp4` | Формат файла |
| `start` | нет | `HH:MM:SS` | — | Начало обрезки |
| `end` | нет | `HH:MM:SS` | — | Конец обрезки |

**Примеры:**

```
GET /download?url=https://youtu.be/aqz-KE-bpKQ
GET /download?url=https://youtu.be/aqz-KE-bpKQ&format=mp3
GET /download?url=https://youtu.be/aqz-KE-bpKQ&start=00:01:00&end=00:02:30
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
| `TPWS_PORT` | `18080` | Порт внутреннего SOCKS5-прокси |
| `TPWS_OPTS` | `--split-pos=1 --oob=tls` | Опции DPI bypass. Для macOS/зарубежных серверов: `""` |
| `OUTPUT_DIR` | `/downloads` | Папка для сохранения файлов |
| `COOKIES_FILE` | `/cookies.txt` | Путь к файлу cookies внутри контейнера |
| `YT_DLP_OPTS` | — | Дополнительные флаги yt-dlp |

## Cookies (обход проверки бота)

YouTube может требовать авторизацию. Экспортируйте cookies из браузера и передайте их в контейнер:

1. Установите расширение [Get cookies.txt LOCALLY](https://chromewebstore.google.com/detail/get-cookiestxt-locally/cclelndahbckbenkjhflpdbgdldlbecc) для Chrome или [cookies.txt](https://addons.mozilla.org/en-US/firefox/addon/cookies-txt/) для Firefox
2. Откройте youtube.com, войдите в аккаунт
3. Экспортируйте cookies в файл `cookies.txt`
4. Передайте файл при запуске:

```bash
# Командная строка
docker run --rm --network=host -v "${PWD}/downloads:/downloads" -v "${PWD}/cookies.txt:/cookies.txt:ro" ghcr.io/olluorg/yt-dlp-dpi:latest "https://youtu.be/aqz-KE-bpKQ"
```

Для веб-интерфейса добавьте в `docker-compose.yml`:
```yaml
volumes:
  - ./cookies.txt:/cookies.txt:ro
```

## Требования

- Docker
- Linux-хост или WSL2

## Основано на

- [bol-van/zapret](https://github.com/bol-van/zapret)
- [Flowseal/zapret-discord-youtube](https://github.com/Flowseal/zapret-discord-youtube)
- [yt-dlp/yt-dlp](https://github.com/yt-dlp/yt-dlp)
