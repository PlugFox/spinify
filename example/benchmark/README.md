# Spinify: benchmark

## Build

```bash
flutter build web --release --no-source-maps --pwa-strategy offline-first --web-renderer canvaskit --web-resources-cdn --base-href /
```

## Deploy

```bash
firebase deploy --only hosting
```

## Docker Compose

Start: `docker-compose up -d`

Stop: `docker-compose down`

Logs: `docker-compose logs -f`

```yaml
services:
  centrifugo-benchmark:
    container_name: centrifugo-benchmark
    image: centrifugo/centrifugo:v5
    restart: unless-stopped
    command: centrifugo --client_insecure --admin
    tty: true
    ports:
      - 8000:8000
    environment:
      - "CENTRIFUGO_ADMIN=true"
      - "CENTRIFUGO_TOKEN_HMAC_SECRET_KEY=80e88856-fe08-4a01-b9fc-73d1d03c2eee"
      - "CENTRIFUGO_ADMIN_PASSWORD=6cec4cc2-960d-4e4a-b650-0cbd4bbf0530"
      - "CENTRIFUGO_ADMIN_SECRET=70957aac-555b-4bce-b9b8-53ada3a8029e"
      - "CENTRIFUGO_API_KEY=8aba9113-d67a-41c6-818a-27aaaaeb64e7"
      - "CENTRIFUGO_ALLOWED_ORIGINS=*"
      - "CENTRIFUGO_HEALTH=true"
      - "CENTRIFUGO_HISTORY_SIZE=10"
      - "CENTRIFUGO_HISTORY_TTL=300s"
      - "CENTRIFUGO_FORCE_RECOVERY=true"
      - "CENTRIFUGO_ALLOW_PUBLISH_FOR_CLIENT=true"
      - "CENTRIFUGO_ALLOW_SUBSCRIBE_FOR_CLIENT=true"
      - "CENTRIFUGO_ALLOW_SUBSCRIBE_FOR_ANONYMOUS=true"
      - "CENTRIFUGO_ALLOW_PUBLISH_FOR_SUBSCRIBER=true"
      - "CENTRIFUGO_ALLOW_PUBLISH_FOR_ANONYMOUS=true"
      - "CENTRIFUGO_ALLOW_USER_LIMITED_CHANNELS=true"
      - "CENTRIFUGO_LOG_LEVEL=debug"
    healthcheck:
      test: ["CMD", "sh", "-c", "wget -nv -O - http://localhost:8000/health"]
      interval: 3s
      timeout: 3s
      retries: 3
    ulimits:
      nofile:
        soft: 65535
        hard: 65535
```
