FROM oven/bun:alpine AS builder
WORKDIR /app
COPY package.json bun.lock bunfig.toml ./
COPY apps/av-service/package.json ./apps/av-service/
RUN bun install --filter "av-service"
COPY ./apps/av-service ./apps/av-service/
COPY ./tsconfig.json ./
WORKDIR /app/apps/av-service
RUN bun build ./index.ts --compile --outfile mycli

FROM clamav/clamav:stable
COPY --from=builder /app/apps/av-service/mycli /usr/local/bin/mycli
CMD ["/usr/local/bin/mycli"]
