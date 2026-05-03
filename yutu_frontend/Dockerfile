# --------------------------------------------------------
# Stage 1: Build Flutter web
# --------------------------------------------------------
FROM ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

# Build the web release bundle
RUN flutter build web --release

# --------------------------------------------------------
# Stage 2: Serve via nginx
# --------------------------------------------------------
FROM nginx:1.27-alpine

COPY --from=builder /app/build/web /usr/share/nginx/html

COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

