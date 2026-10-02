# A built image, like ../consumer — `git pull && docker compose up -d` will NOT
# pick up changes to main.go; you need --build. See ../../README.md under
# "## Kafka Testing Stack".
FROM golang:1.27.1-alpine AS build

WORKDIR /src

# Copied before the source so image rebuilds after a code edit reuse the module layer.
COPY go.mod go.sum ./
RUN go mod download

COPY main.go .
# Static binary: franz-go is pure Go, so no cgo and no libc needed at runtime.
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /producer .

FROM gcr.io/distroless/static:nonroot
COPY --from=build /producer /producer
EXPOSE 8080
ENTRYPOINT ["/producer"]
