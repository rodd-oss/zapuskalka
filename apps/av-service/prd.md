# AV Scanning Microservice - Product Requirements Document

## Overview
A continuous antivirus scanning service that integrates with the Zapuskalka backend to scan uploaded build artifacts for malware using ClamAV. The service runs as a standalone Docker container, authenticates as a PocketBase superuser, and processes build files in real-time using PocketBase subscriptions.

## Goals
1. **Security Assurance:** Ensure all user-uploaded build artifacts are scanned for viruses before being made available for download.
2. **Real-time Processing:** Scan builds as soon as they're uploaded using PocketBase real-time subscriptions.
3. **Reliability:** Handle network interruptions, ClamAV failures, and database errors gracefully.
4. **Auditability:** Maintain detailed logs of scan results, including virus detections and errors.
5. **Resource Efficiency:** Delete downloaded files immediately after scanning to minimize disk usage.

## Non-Goals
1. Scanning files outside the `app_builds` collection.
2. Providing heuristic analysis beyond ClamAV's signature-based detection.
3. Scanning encrypted or password-protected archives.
4. Real-time scanning of running processes.

## Data Model
The service interacts with two PocketBase collections:

### `app_builds`
- `id`: Record ID
- `files`: Array of file attachments (artifacts to scan)
- `os`, `arch`, `branch`, `app`: Build metadata

### `av_build_checks` (new)
- `build`: Relation to `app_builds` record
- `status`: Enum (`pending`, `scanning`, `clean`, `infected`, `error`)
- `virus_name`: Detected virus name (if infected)
- `scan_time`: Timestamp when scan completed
- `log`: Detailed scan output/errors
- `created`, `updated`: System timestamps

## Architecture

### Components
1. **Auth Manager:** Authenticates as PocketBase superuser using `pb.collection("_superusers").authWithPassword()`.
2. **Build Discovery:** On startup, finds all `app_builds` records that don't have a corresponding `av_build_checks` record.
3. **Subscription Handler:** Subscribes to `app_builds` collection for new build uploads.
4. **Check Creator:** Creates `av_build_checks` records with `status="pending"` for newly discovered builds.
5. **Build Processor:** For each pending AV check:
   - Updates status to `"scanning"`
   - Downloads all files from `app_builds.files` to temporary directory
   - Runs `clamscan` on each file via Bun shell
   - Records results (status, virus_name, scan_time, log)
   - Deletes temporary files

### Flow
```
Start → Superuser Auth → Find builds without AV checks
        ↓
   Create av_build_checks (pending) → Subscribe to app_builds
        ↓
   Wait for new builds
        ↓
On new app_builds record:
  1. Create av_build_checks record (pending)
  2. Queue check for processing
        ↓
Process AV check:
  1. Update status → "scanning"
  2. For each file in build.files:
     a. Download to /tmp
     b. Run clamscan --quiet --infected --no-summary
     c. Capture exit code & output
  3. Determine final status:
     - Exit 0 → "clean"
     - Exit 1 → "infected" (extract virus name)
     - Exit 2 → "error" (log output)
  4. Update av_build_checks record
  5. Delete temporary files
```

## Implementation Details

### Technology Stack
- **Runtime:** Bun (TypeScript)
- **Database Client:** PocketBase JS SDK (`backend-api` package)
- **AV Engine:** ClamAV (`clamscan` binary)
- **Container:** Docker (based on `oven/bun:alpine` + `clamav/clamav:stable`)

### Key Functions
1. `authenticate()`: Logs in with superuser credentials.
2. `scanExistingBuildsWithoutChecks()`: Finds and queues builds missing AV checks.
3. `subscribeToNewBuilds()`: Subscribes to new app_builds records.
4. `createAvBuildCheck(buildId)`: Creates av_build_checks record (or queues existing).
5. `processBuildCheck(recordId)`: Main scanning logic.
6. `scanBuildFile(buildId, fileName)`: Downloads, scans, and returns result.
7. `markAsClean() / markAsInfected() / markAsError()`: Update av_build_checks status.

### Error Handling
- **Network failures:** Retry downloads (max 3 attempts) with exponential backoff.
- **ClamAV errors:** Log output, mark status as `"error"`.
- **Database errors:** Log and retry with circuit breaker.
- **Missing files:** Skip build, mark as `"error"`.

## Environment Variables
```bash
# Required
POCKETBASE_URL=http://localhost:8090
POCKETBASE_SUPERUSER_EMAIL=admin@example.com
POCKETBASE_SUPERUSER_PASSWORD=********

# Optional (with defaults)
CLAMSCAN_PATH=clamscan                    # Path to clamscan binary
WORK_DIR=/tmp/zapuskalka-av-scans         # Temporary directory
MAX_RETRIES=3                             # Download retry attempts
LOG_LEVEL=info                            # debug, info, warn, error
```

## Deployment

### Docker Container
```dockerfile
FROM oven/bun:alpine AS builder
WORKDIR /app
COPY package.json bun.lock bunfig.toml ./
COPY apps/av-service/package.json ./apps/av-service/
RUN bun install --filter "av-service"
COPY ./apps/av-service ./apps/av-service/
COPY ./tsconfig.json ./
WORKDIR /app/apps/av-service
RUN bun build ./index.ts --compile --outfile av-scanner

FROM clamav/clamav:stable
COPY --from=builder /app/apps/av-service/av-scanner /usr/local/bin/av-scanner
CMD ["av-scanner"]
```

### Running Locally
```bash
cd apps/av-service
bun install
bun run index.ts
```

### Production Deployment
1. Build and push Docker image: `docker build -f av.Dockerfile -t av-scanner .`
2. Run with environment variables: `docker run --env-file .env av-scanner`
3. Ensure container has network access to PocketBase backend.

## Testing

### Unit Tests
- Mock PocketBase client responses
- Test scan result parsing
- Test error handling scenarios

### Integration Tests
1. Start local PocketBase with test data.
2. Run scanner against test builds.
3. Verify av_build_checks records are updated correctly.

### Manual Testing
```bash
# Create test build with dummy file (scanner will auto-create AV check)
pb create app_builds '{"files": ["test.exe"]}'

# Wait for scanner to process (check logs)
# Verify av_build_checks record was created and updated
pb list av_build_checks --filter 'build = "BUILD_ID"'
```

## Monitoring

### Logs
- Scan start/end timestamps
- Files processed and results
- Errors with stack traces

### Metrics (Future)
- Builds processed per hour
- Scan success/failure rates
- Average scan duration
- Virus detection counts

### Health Checks
- Periodic ping to PocketBase
- ClamAV binary availability check
- Disk space monitoring

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| ClamAV signature outdated | Regular container updates; monitor ClamAV version |
| High memory usage during scans | Limit concurrent scans; monitor container resources |
| Database connection loss | Implement reconnection logic with exponential backoff |
| Malicious files escaping scan | Run in isolated container; no external network access |
| False positives | Manual review process for flagged builds |

## Future Enhancements
1. **Parallel Scanning:** Process multiple builds concurrently.
2. **Signature Auto-update:** Refresh ClamAV databases periodically.
3. **Webhook Integration:** Notify external systems of infected builds.
4. **Scan History:** Keep historical scan results for audit.
5. **Multiple AV Engines:** Add support for additional scanners.

## Success Criteria
1. All uploaded builds are scanned within 5 minutes of upload.
2. Zero unprocessed `pending` records older than 10 minutes.
3. Less than 1% error rate in scan operations.
4. Complete audit trail for infected builds.

---

*Last Updated: 2025-12-10*  
*Owners: Infrastructure Team*