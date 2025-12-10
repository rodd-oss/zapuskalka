import { newApiClient, type TypedPocketBase } from "backend-api";
import type { AppBuildsResponse, AvBuildChecksResponse } from "backend-api";
import { $ } from "bun";
import EventSource from 'eventsource';
(global as any).EventSource = EventSource;

const POCKETBASE_URL = Bun.env.POCKETBASE_URL ?? "http://localhost:8090";
const POCKETBASE_SUPERUSER_EMAIL = Bun.env.POCKETBASE_SUPERUSER_EMAIL;
const POCKETBASE_SUPERUSER_PASSWORD = Bun.env.POCKETBASE_SUPERUSER_PASSWORD;
const CLAMSCAN_PATH = Bun.env.CLAMSCAN_PATH ?? "clamscan";
const WORK_DIR = Bun.env.WORK_DIR ?? "/tmp/zapuskalka-av-scans";
const MAX_RETRIES = parseInt(Bun.env.MAX_RETRIES ?? "3", 10) || 3;
const LOG_LEVEL = Bun.env.LOG_LEVEL ?? "info";
const POLL_INTERVAL_MS = parseInt(Bun.env.POLL_INTERVAL_MS ?? "30000", 10) || 30000;

const logger = {
  debug: (...args: unknown[]) =>
    LOG_LEVEL === "debug" && console.log("[DEBUG]", ...args),
  info: (...args: unknown[]) => console.log("[INFO]", ...args),
  warn: (...args: unknown[]) => console.log("[WARN]", ...args),
  error: (...args: unknown[]) => console.log("[ERROR]", ...args),
};

interface ScanResult {
  infected: boolean;
  virusName: string;
  log: string;
}

// --- State ---
let scanQueue: Set<string> = new Set();
let isProcessing = false;

// --- PocketBase client ---
function createPocketBaseClient(): TypedPocketBase {
  const pb = newApiClient(POCKETBASE_URL);
  pb.autoCancellation(false);
  return pb;
}

// --- Authentication ---
async function authenticate(pb: TypedPocketBase): Promise<void> {
  const email = POCKETBASE_SUPERUSER_EMAIL;
  const password = POCKETBASE_SUPERUSER_PASSWORD;

  if (!email || !password) {
    throw new Error("Missing PocketBase superuser credentials");
  }

  try {
    await pb.collection("_superusers").authWithPassword(email, password);
    logger.info("Authenticated as superuser");
  } catch (error) {
    throw new Error(`Superuser authentication failed: ${error}`);
  }
}

// --- Work directory ---
async function ensureWorkDir(): Promise<void> {
  try {
    await $`mkdir -p ${WORK_DIR}`;
    logger.debug(`Work directory ensured: ${WORK_DIR}`);
  } catch (error) {
    throw new Error(`Failed to create work directory: ${error}`);
  }
}

// --- Check if build has files ---
async function buildHasFiles(
  pb: TypedPocketBase,
  buildId: string,
): Promise<boolean> {
  try {
    const build = (await pb.collection("app_builds").getOne(buildId)) as AppBuildsResponse;
    return !!(build.files && build.files.length > 0);
  } catch (error) {
    logger.error(`Failed to fetch build ${buildId}:`, error);
    return false;
  }
}

// --- AV check creation ---
async function createAvBuildCheck(
  pb: TypedPocketBase,
  buildId: string,
): Promise<boolean> {
  try {
    // Check if av_build_checks already exists for this build
    const existing = (await pb.collection("av_build_checks").getFullList({
      filter: `build = '${buildId}'`,
    })) as AvBuildChecksResponse[];
    if (existing.length > 0) {
      logger.debug(`AV check already exists for build ${buildId}`);
      // Queue existing check ID
      scanQueue.add(existing[0]!.id);
      processQueue(pb);
      return true;
    }

    // Check if build has files before creating check
    const hasFiles = await buildHasFiles(pb, buildId);
    if (!hasFiles) {
      logger.debug(`Build ${buildId} has no files, skipping AV check creation`);
      return false;
    }

    // Create new av_build_checks record
    const record = (await pb.collection("av_build_checks").create({
      build: buildId,
      status: "pending",
    })) as AvBuildChecksResponse;
    logger.debug(`Created AV check ${record.id} for build ${buildId}`);
    scanQueue.add(record.id);
    processQueue(pb);
    return true;
  } catch (error) {
    logger.error(`Failed to create AV check for build ${buildId}:`, error);
    return false;
  }
}

// --- Reprocess stuck or failed checks ---
async function reprocessStuckOrFailedChecks(
  pb: TypedPocketBase,
): Promise<void> {
  try {
    // Get all av_build_checks to find stuck/failed ones
    const existingChecks = (await pb
      .collection("av_build_checks")
      .getFullList()) as AvBuildChecksResponse[];

    // Queue any existing checks that are still in scanning or error state
    // (e.g., from previous scanner crashes or transient failures)
    const stuckOrFailedChecks = existingChecks.filter(
      (check) => check.status === "scanning" || check.status === "error",
    );
    if (stuckOrFailedChecks.length > 0) {
      logger.info(
        `Found ${stuckOrFailedChecks.length} checks in scanning/error state, queuing for reprocessing`,
      );
      for (const check of stuckOrFailedChecks) {
        scanQueue.add(check.id);
      }
      processQueue(pb);
    }
  } catch (error) {
    logger.error("Failed to reprocess stuck/failed checks:", error);
  }
}

// --- Long polling for unchecked builds ---
async function fetchAndQueueOneUncheckedBuild(
  pb: TypedPocketBase,
): Promise<boolean> {
  try {
    // Get all av_build_checks to know which builds are already checked
    // We only need the build IDs
    const existingChecks = (await pb
      .collection("av_build_checks")
      .getFullList({
        fields: "build",
      })) as Pick<AvBuildChecksResponse, "build">[];
    const checkedBuildIds = new Set(existingChecks.map((check) => check.build));

    // Fetch builds in batches, oldest first to process backlog
    const pageSize = 10;
    let page = 1;
    let hasMore = true;

    while (hasMore) {
      const result = await pb.collection("app_builds").getList(page, pageSize, {
        sort: "created", // oldest first
      });

      const builds = result.items as AppBuildsResponse[];
      if (builds.length === 0) {
        return false; // No builds at all
      }

      // Find first build without a check
      for (const build of builds) {
        if (!checkedBuildIds.has(build.id)) {
          // Create AV check for this build (function handles atomicity)
          const checkCreated = await createAvBuildCheck(pb, build.id);
          if (checkCreated) {
            return true; // Successfully queued one build
          }
          // Check was not created (likely no files), continue to next build
        }
      }

      // Check if we've reached the end
      if (builds.length < pageSize) {
        hasMore = false;
      } else {
        page++;
      }
    }

    return false; // No unchecked builds found
  } catch (error) {
    logger.error("Failed to fetch unchecked builds:", error);
    return false;
  }
}

async function startLongPolling(pb: TypedPocketBase): Promise<void> {
  const pollInterval = POLL_INTERVAL_MS;
  
  async function poll() {
    // Only poll if queue is empty and not processing
    if (scanQueue.size > 0 || isProcessing) {
      logger.debug("Long poll skipped: queue not empty or processing");
      // Schedule next poll anyway
      setTimeout(poll, pollInterval);
      return;
    }
    
    try {
      const queued = await fetchAndQueueOneUncheckedBuild(pb);
      if (queued) {
        logger.debug("Long poll: queued one unchecked build");
      } else {
        logger.debug("Long poll: no unchecked builds found");
      }
    } catch (error) {
      logger.error("Long poll error:", error);
    } finally {
      // Schedule next poll
      setTimeout(poll, pollInterval);
    }
  }

  // Start first poll after a short delay
  setTimeout(poll, 1000);
  logger.info(`Long polling started (interval: ${pollInterval}ms)`);
}

// --- Subscription to new builds ---
async function subscribeToNewBuilds(pb: TypedPocketBase): Promise<void> {
  try {
    await pb.collection("app_builds").subscribe("*", (data) => {
      if (data.action === "create") {
        const buildId = data.record.id;
        logger.debug("New build received:", buildId);
        // Create AV check for this build
        createAvBuildCheck(pb, buildId);
      }
    });

    logger.info("Subscribed to app_builds collection");
  } catch (error) {
    logger.error("Failed to subscribe to app_builds collection:", error);
    throw error;
  }
}

// --- Queue processing ---
async function processQueue(pb: TypedPocketBase): Promise<void> {
  if (isProcessing || scanQueue.size === 0) {
    // Queue is empty and not processing - try to fetch more work
    if (scanQueue.size === 0 && !isProcessing) {
      try {
        const queued = await fetchAndQueueOneUncheckedBuild(pb);
        if (queued) {
          logger.debug("Immediate poll: queued one unchecked build");
        }
      } catch (error) {
        logger.error("Immediate poll error:", error);
      }
    }
    return;
  }

  isProcessing = true;
  const recordId = scanQueue.values().next().value!;
  scanQueue.delete(recordId);

  try {
    await processBuildCheck(pb, recordId);
  } catch (error) {
    logger.error(`Failed to process check ${recordId}:`, error);
    // Requeue with delay? For now, just log
  } finally {
    isProcessing = false;
    // Process next item if any
    setTimeout(() => processQueue(pb), 0);
  }
}

// --- Process a single build check ---
async function processBuildCheck(
  pb: TypedPocketBase,
  recordId: string,
): Promise<void> {
  logger.info(`Processing build check: ${recordId}`);

  // Update status to scanning
  await pb.collection("av_build_checks").update(recordId, {
    status: "scanning",
    scan_time: new Date().toISOString(),
  });

  let checkRecord: AvBuildChecksResponse<{ build: AppBuildsResponse }>;
  let buildRecord: AppBuildsResponse;

  try {
    checkRecord = (await pb.collection("av_build_checks").getOne(recordId, {
      expand: "build",
    })) as AvBuildChecksResponse<{ build: AppBuildsResponse }>;

    if (!checkRecord.expand?.build) {
      throw new Error(`Build not found for check ${recordId}`);
    }

    buildRecord = checkRecord.expand.build;
  } catch (error) {
    await markAsError(pb, recordId, `Failed to fetch records: ${error}`);
    return;
  }

  if (!buildRecord.files || buildRecord.files.length === 0) {
    await markAsClean(pb, recordId, "No files to scan");
    return;
  }

  let infectedFound = false;
  let virusName = "";
  let scanLog = "";

  for (const fileName of buildRecord.files) {
    try {
      const result = await scanBuildFile(pb, buildRecord.id, fileName);
      scanLog += `File: ${fileName}\n${result.log}\n\n`;

      if (result.infected) {
        infectedFound = true;
        virusName = result.virusName;
        // First infection wins
        break;
      }
    } catch (error) {
      scanLog += `File: ${fileName}\nERROR: ${error}\n\n`;
      await markAsError(
        pb,
        recordId,
        `File scan failed: ${error}\n\n${scanLog}`,
      );
      return;
    }
  }

  // Clean up downloaded files
  await cleanupBuildFiles(buildRecord.id);

  if (infectedFound) {
    await markAsInfected(pb, recordId, virusName, scanLog);
  } else {
    await markAsClean(pb, recordId, scanLog);
  }
}

// --- Scan a single file ---
async function scanBuildFile(
  pb: TypedPocketBase,
  buildId: string,
  fileName: string,
): Promise<ScanResult> {
  const fileUrl = pb.files.getURL(
    { id: buildId, collectionId: "app_builds" },
    fileName,
  );
  const localPath = `${WORK_DIR}/${buildId}_${fileName.replace(/[^a-zA-Z0-9._-]/g, "_")}`;

  // Download file with retries
  for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
    try {
      const response = await fetch(fileUrl);
      if (!response.ok) throw new Error(`HTTP ${response.status}`);

      const arrayBuffer = await response.arrayBuffer();
      await Bun.write(localPath, arrayBuffer);
      break;
    } catch (error) {
      if (attempt === MAX_RETRIES) {
        throw new Error(
          `Download failed after ${MAX_RETRIES} attempts: ${error}`,
        );
      }
      await new Promise((resolve) => setTimeout(resolve, 1000 * attempt));
    }
  }

  // Run clamscan
  try {
    const result =
      await $`${CLAMSCAN_PATH} --quiet --infected --no-summary ${localPath}`;
    const output = result.stderr.toString() + result.stdout.toString();

    // clamscan exit codes: 0=clean, 1=infected, 2=error
    if (result.exitCode === 1) {
      // Extract virus name from output (format: "localPath: VirusName FOUND")
      const match = output.match(/: (.+) FOUND/);
      return {
        infected: true,
        virusName: match?.[1] || "Unknown",
        log: output.trim(),
      };
    } else if (result.exitCode === 0) {
      return {
        infected: false,
        virusName: "",
        log: output.trim() || "Clean",
      };
    } else {
      throw new Error(`ClamAV error (exit ${result.exitCode}): ${output}`);
    }
  } finally {
    // Delete local file
    try {
      await $`rm -f ${localPath}`;
    } catch {
      // Ignore cleanup errors
    }
  }
}

// --- Cleanup downloaded files for a build ---
async function cleanupBuildFiles(buildId: string): Promise<void> {
  try {
    const files = await $`ls ${WORK_DIR}/${buildId}_* 2>/dev/null || true`;
    for (const file of files.text().split("\n").filter(Boolean)) {
      await $`rm -f ${file}`;
    }
  } catch (error) {
    logger.warn(`Failed to cleanup files for build ${buildId}:`, error);
  }
}

// --- Status update helpers ---
async function markAsClean(
  pb: TypedPocketBase,
  recordId: string,
  log: string,
): Promise<void> {
  await pb.collection("av_build_checks").update(recordId, {
    status: "clean",
    scan_time: new Date().toISOString(),
    log: log.slice(0, 1000), // Limit log size
  });
  logger.info(`Build check ${recordId} marked as clean`);
}

async function markAsInfected(
  pb: TypedPocketBase,
  recordId: string,
  virusName: string,
  log: string,
): Promise<void> {
  await pb.collection("av_build_checks").update(recordId, {
    status: "infected",
    virus_name: virusName,
    scan_time: new Date().toISOString(),
    log: log.slice(0, 1000),
  });
  logger.warn(`Build check ${recordId} marked as infected: ${virusName}`);
}

async function markAsError(
  pb: TypedPocketBase,
  recordId: string,
  log: string,
): Promise<void> {
  await pb.collection("av_build_checks").update(recordId, {
    status: "error",
    scan_time: new Date().toISOString(),
    log: log.slice(0, 1000),
  });
  logger.error(`Build check ${recordId} marked as error`);
}

// --- Main entry point ---
async function startScanner(): Promise<void> {
  const pb = createPocketBaseClient();

  try {
    await authenticate(pb);
    await ensureWorkDir();
    await reprocessStuckOrFailedChecks(pb);
    await subscribeToNewBuilds(pb);
    await startLongPolling(pb);
    logger.info("AV Scanner started successfully");
  } catch (error) {
    logger.error("Failed to start AV Scanner:", error);
    process.exit(1);
  }
}

// --- Graceful shutdown ---
process.on("SIGINT", () => {
  logger.info("Shutting down...");
  process.exit(0);
});

process.on("SIGTERM", () => {
  logger.info("Terminating...");
  process.exit(0);
});

// --- Start the scanner ---
startScanner().catch((error) => {
  logger.error("Unhandled error in scanner:", error);
  process.exit(1);
});
