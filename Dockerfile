#####################################
#BACKEND#
#####################################
FROM golang:1.25-alpine AS build-backend
WORKDIR /app
COPY backend/go.mod backend/go.sum ./
RUN go mod download
COPY ./backend ./
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o dist/main.bin .

#####################################
# FRONTEND #
#####################################
# FROM node:lts-alpine AS build-frontend
FROM oven/bun:1 AS build-frontend
WORKDIR /app
COPY package.json bun.lock bunfig.toml ./
COPY apps/frontend/package.json ./apps/frontend/
COPY packages/backend-api/package.json ./packages/backend-api/
RUN bun install --filter "frontend" --filter './packages/*'
COPY ./apps/frontend ./apps/frontend/
COPY ./packages ./packages/
COPY ./tsconfig.json ./
WORKDIR /app/apps/frontend
ARG VITE_GIT_SHORT_LINK
ENV VITE_GIT_SHORT_LINK=$VITE_GIT_SHORT_LINK
ARG VITE_BACKEND_URL
ENV VITE_BACKEND_URL=$VITE_BACKEND_URL
RUN bun run build

#####################################
# FINAL IMAGE #
#####################################
FROM alpine:latest
WORKDIR /app
# Copy backend binary and migrations
COPY --from=build-backend /app/dist/main.bin ./
# COPY --from=build-backend /app/migrations ./migrations
# Copy frontend build
COPY --from=build-frontend /app/apps/frontend/dist ./dist

EXPOSE 8090

ENTRYPOINT ["./main.bin", "serve", "--http=0.0.0.0:8090"]
