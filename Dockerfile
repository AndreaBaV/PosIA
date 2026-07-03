# Dockerfile en la RAÍZ del monorepo — usado por Northflank y cualquier PaaS
# que compile desde la raíz. Contexto = raíz para incluir packages/posia_core.
FROM dart:stable AS construir
WORKDIR /app

COPY packages/posia_core/pubspec.yaml packages/posia_core/
COPY packages/posia_core/lib packages/posia_core/lib/
COPY packages/posia_core/analysis_options.yaml packages/posia_core/

COPY server/sync_api/pubspec.yaml server/sync_api/
WORKDIR /app/server/sync_api
RUN dart pub get

COPY server/sync_api/ ./
RUN dart compile exe bin/server.dart -o /app/server/sync_api/server

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=construir /app/server/sync_api/server /app/server
ENV PORT=8080
EXPOSE 8080
CMD ["/app/server"]
