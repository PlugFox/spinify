# Spinify: benchmark

## Build

```bash
flutter build web --release --no-source-maps --pwa-strategy offline-first --web-renderer canvaskit --web-resources-cdn --base-href /
```

## Deploy

```bash
firebase deploy --only hosting
```
