#####################################
#BACKEND#
#####################################
FROM golang:1.25-alpine AS build-backend
WORKDIR /app
COPY ./backend ./
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o dist/main.bin .

#####################################
# FRONTEND #
#####################################
# FROM node:lts-alpine AS build-frontend
# WORKDIR /app/frontend
# COPY ./frontend/package*.json ./
# RUN npm ci
# COPY ./frontend ./
# RUN npm run build

#####################################
# FINAL IMAGE #
#####################################
FROM alpine:latest
WORKDIR /app
# Copy backend binary and migrations
COPY --from=build-backend /app/dist/main.bin ./
# COPY --from=build-backend /app/migrations ./migrations
# Copy frontend build
# COPY --from=build-frontend /app/frontend/dist ./dist

EXPOSE 8090

ENTRYPOINT ["./main.bin", "serve", "--http=0.0.0.0:8090"]
