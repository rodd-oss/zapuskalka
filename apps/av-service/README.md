# AV Scanning Microservice

Real-time antivirus scanning service for Zapuskalka build artifacts using ClamAV.

## Overview

This service continuously monitors the `app_builds` collection in PocketBase, creates AV check records for new builds, and scans associated files for viruses using ClamAV. It runs as a standalone Docker container and requires superuser access to the PocketBase backend.

## Features

- **Real-time scanning:** Subscribes to new `app_builds` records via PocketBase real-time API.
- **Batch processing:** Scans existing builds without AV checks on startup.
- **Retry logic:** Automatic retry for failed downloads (configurable attempts).
- **Cleanup:** Temporary files deleted immediately after scanning.
- **Comprehensive logging:** Scan results stored in `av_build_checks` records.

## Data Model

The service interacts with two collections:

| Collection | Fields Used |
|------------|-------------|
| `app_builds` | `id`, `files` (array of file attachments) |
| `av_build_checks` | `id`, `build` (relation), `status`, `virus_name`, `scan_time`, `log` |

## Environment Variables

Create a `.env` file based on `.env.example`:

```bash
# Required
POCKETBASE_URL=http://localhost:8090
POCKETBASE_SUPERUSER_EMAIL=admin@example.com
POCKETBASE_SUPERUSER_PASSWORD=********

# Optional (defaults shown)
CLAMSCAN_PATH=clamscan
WORK_DIR=/tmp/zapuskalka-av-scans
MAX_RETRIES=3
LOG_LEVEL=info
```

## Running Locally

### Prerequisites
- [Bun](https://bun.sh) v1.3.2+
- [ClamAV](https://clamav.net) installed and `clamscan` in PATH
- Running PocketBase instance with superuser credentials

### Development
```bash
cd apps/av-service
bun install
bun run dev
```

### Production (Docker)
```bash
# Build image
docker build -f av.Dockerfile -t av-scanner .

# Run container
docker run -d \
  --name av-scanner \
  --env-file .env \
  --platform linux/amd64 \
  av-scanner
```

## Docker Image

The Docker image is based on `clamav/clamav:stable` with the Bun-compiled scanner binary.

### Building
```bash
docker build -f av.Dockerfile -t av-scanner --platform linux/amd64 .
```

### Testing
```bash
# Test with dummy credentials (should fail with authentication error)
docker run --rm -e POCKETBASE_URL=http://localhost:8090 -e POCKETBASE_SUPERUSER_EMAIL=test -e POCKETBASE_SUPERUSER_PASSWORD=test av-scanner
```

## Architecture

1. **Authentication:** Superuser login via `pb.collection("_superusers").authWithPassword()`.
2. **Build Discovery:** On startup, finds all `app_builds` records without corresponding `av_build_checks` records.
3. **Subscription:** Real-time subscription to `app_builds` collection for new builds.
4. **Check Creation:** Creates `av_build_checks` records with `status="pending"` for discovered and new builds.
5. **Processing:** For each pending AV check:
   - Download all files to temporary directory.
   - Run `clamscan` on each file.
   - Update status (`clean`, `infected`, `error`).
   - Delete temporary files.
6. **Error Handling:** Failed scans are logged and marked as `error`.

## Monitoring

Check logs for:
- `[INFO]` – Startup, authentication, scan completion.
- `[WARN]` – Infected files detected.
- `[ERROR]` – Authentication failures, download errors, ClamAV errors.

Scan results are stored in `av_build_checks` records with timestamps and detailed logs.

## Integration with Backend

The scanner automatically creates `av_build_checks` records for new `app_builds` records. The backend does not need to create them manually, but if it does, the scanner will detect existing records and process them.

Example PocketBase hook (optional – scanner handles this automatically):
```javascript
onRecordCreate('app_builds', (record) => {
  // Optional: create av_build_checks record
  // Scanner will handle duplicates gracefully
  create('av_build_checks', {
    build: record.id,
    status: 'pending'
  })
})
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Missing PocketBase superuser credentials" | Set `POCKETBASE_SUPERUSER_EMAIL` and `POCKETBASE_SUPERUSER_PASSWORD` environment variables. |
| "Could not resolve: backend-api" | Ensure `packages/backend-api` is installed (run `bun install` in monorepo root). |
| "ClamAV error (exit 2)" | Verify `clamscan` binary is installed and virus databases are updated (`freshclam`). |
| "Download failed" | Check network connectivity to PocketBase instance and file permissions. |

## License

Part of the Zapuskalka project. See root LICENSE file.
