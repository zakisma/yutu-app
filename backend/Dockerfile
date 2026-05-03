# --------------------------------------------------------
# Stage 1: Build
# --------------------------------------------------------
FROM golang:1.25-alpine AS builder

WORKDIR /app

                                                                   
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -o /app/api ./cmd/api/main.go

# --------------------------------------------------------
# Stage 2: Runtime
# --------------------------------------------------------
FROM alpine:3.20

RUN apk add --no-cache ca-certificates

WORKDIR /app

COPY --from=builder /app/api /app/api

EXPOSE 8080

CMD ["/app/api"]


