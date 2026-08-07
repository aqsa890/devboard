FROM golang:1.22-alpine AS builder

WORKDIR /app

RUN apk add --no-cache ca-certificates

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64 \
    go build \
    -ldflags="-s -w" \
    -trimpath \
    -o server .

FROM alpine:3.19

RUN apk --no-cache add ca-certificates

RUN addgroup -S appgroup -g 10001 && \
    adduser -S appuser -u 10001 -G appgroup

WORKDIR /app

COPY --from=builder --chown=appuser:appgroup /app/server .

USER appuser:appgroup

EXPOSE 8080

ENTRYPOINT ["./server"]