# Dockerfile для сервера на Dart
FROM dart:stable AS backend_build

# Установим рабочую директорию
WORKDIR /app

# Копируем pubspec и pubspec.lock для установки зависимостей
COPY pubspec.* ./

# Устанавливаем зависимости
RUN dart pub get

# Копируем остальной код приложения
COPY . .

# Компилируем серверное приложение
RUN dart compile exe bin/main.dart -o /server

# Финальный образ
FROM debian:bullseye-slim

# Устанавливаем необходимые зависимости
RUN apt-get update && apt-get install -y \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Копируем скомпилированный сервер
COPY --from=backend_build /server /usr/local/bin/server

# Порт для сервера
EXPOSE 8080

# Команда запуска сервера
CMD ["/usr/local/bin/server"]