# Dockerfile для веб-приложения Dart (JS)
FROM dart:stable AS frontend_build

# Установим рабочую директорию
WORKDIR /app

# Копируем pubspec и pubspec.lock для установки зависимостей
COPY pubspec.* ./

# Устанавливаем зависимости
RUN dart pub get

# Копируем остальной код приложения
COPY . .

# Сборка JS
#RUN dart compile js -O3 -o build/main.dart.js web/main.dart
RUN dart pub global activate webdev && webdev build --output=build --release

# Финальный образ для сервиса на NGINX
FROM nginx:alpine

# Копируем скомпилированные файлы
COPY --from=frontend_build /app/build/web /usr/share/nginx/html

# Порт для NGINX
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
