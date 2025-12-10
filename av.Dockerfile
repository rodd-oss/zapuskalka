FROM oven/bun:alpine AS builder
WORKDIR /app
COPY package.json bun.lock bunfig.toml ./
COPY apps/av-service/package.json ./apps/av-service/
COPY packages/backend-api/package.json ./packages/backend-api/
RUN bun install --filter "av-service" --filter './packages/*'
COPY ./apps/av-service ./apps/av-service/
COPY ./packages ./packages/
COPY ./tsconfig.json ./
WORKDIR /app/apps/av-service
RUN bun build ./index.ts --compile --outfile av-scanner

FROM clamav/clamav:stable
COPY --from=builder /app/apps/av-service/av-scanner /usr/local/bin/av-scanner
CMD ["/usr/local/bin/av-scanner"]
