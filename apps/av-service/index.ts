import { newApiClient, type TypedPocketBase } from "backend-api";
import type { AppBuildsResponse, AvBuildChecksResponse } from "backend-api";
import { $ } from "bun";

const POCKETBASE_URL = Bun.env.POCKETBASE_URL ?? "http://localhost:8090";
const POCKETBASE_SUPERUSER_EMAIL = Bun.env.POCKETBASE_SUPERUSER_EMAIL;
const POCKETBASE_SUPERUSER_PASSWORD = Bun.env.POCKETBASE_SUPERUSER_PASSWORD;
const CLAMSCAN_PATH = Bun.env.CLAMSCAN_PATH ?? "clamscan";
const WORK_DIR = Bun.env.WORK_DIR ?? "/tmp/zapuskalka-av-scans";
const MAX_RETRIES = parseInt(Bun.env.MAX_RETRIES ?? "3", 10) || 3;
const LOG_LEVEL = Bun.env.LOG_LEVEL ?? "info";

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

class AVScanner {
  private pb: TypedPocketBase;
  private scanQueue: Set<string> = new Set();
  private isProcessing = false;
  private maxRetries = MAX_RETRIES;

  constructor() {
    this.pb = newApiClient(POCKETBASE_URL);
    this.pb.autoCancellation(false);
  }

  async start() {
    try {
      await this.authenticate();
      await this.ensureWorkDir();
      await this.scanExistingBuildsWithoutChecks();
      await this.subscribeToNewBuilds();
      logger.info("AV Scanner started successfully");
    } catch (error) {
      logger.error("Failed to start AV Scanner:", error);
      process.exit(1);
    }
  }

  private async authenticate() {
    const email = POCKETBASE_SUPERUSER_EMAIL;
    const password = POCKETBASE_SUPERUSER_PASSWORD;

    if (!email || !password) {
      throw new Error("Missing PocketBase superuser credentials");
    }

    try {
      await this.pb.collection("_superusers").authWithPassword(email, password);
      logger.info("Authenticated as superuser");
    } catch (error) {
      throw new Error(`Superuser authentication failed: ${error}`);
    }
  }

  private async ensureWorkDir() {
    try {
      await $`mkdir -p ${WORK_DIR}`;
      logger.debug(`Work directory ensured: ${WORK_DIR}`);
    } catch (error) {
      throw new Error(`Failed to create work directory: ${error}`);
    }
  }

  private async scanExistingBuildsWithoutChecks() {
    try {
      // Get all av_build_checks to find which builds already have checks
      const existingChecks = (await this.pb
        .collection("av_build_checks")
        .getFullList()) as AvBuildChecksResponse[];
      const checkedBuildIds = new Set(existingChecks.map((check) => check.build));

      // Get all app_builds that don't have checks
      const allBuilds = (await this.pb
        .collection("app_builds")
        .getFullList()) as AppBuildsResponse[];
      const buildsWithoutChecks = allBuilds.filter(
        (build) => !checkedBuildIds.has(build.id),
      );

      logger.info(
        `Found ${buildsWithoutChecks.length} builds without AV checks (total builds: ${allBuilds.length})`,
      );

      // Create av_build_checks records for each missing build
      for (const build of buildsWithoutChecks) {
        await this.createAvBuildCheck(build.id);
      }

      // Also queue any existing checks that are still in scanning or error state
      // (e.g., from previous scanner crashes or transient failures)
      const stuckOrFailedChecks = existingChecks.filter(
        (check) => check.status === "scanning" || check.status === "error",
      );
      if (stuckOrFailedChecks.length > 0) {
        logger.info(
          `Found ${stuckOrFailedChecks.length} checks in scanning/error state, queuing for reprocessing`,
        );
        for (const check of stuckOrFailedChecks) {
          this.scanQueue.add(check.id);
        }
        this.processQueue();
      }
    } catch (error) {
      logger.error("Failed to scan existing builds without checks:", error);
    }
  }

  private async createAvBuildCheck(buildId: string) {
    try {
      // Check if av_build_checks already exists for this build
      const existing = (await this.pb
        .collection("av_build_checks")
        .getFullList({
          filter: `build = '${buildId}'`,
        })) as AvBuildChecksResponse[];
      if (existing.length > 0) {
        logger.debug(`AV check already exists for build ${buildId}`);
        // Queue existing check ID
        this.scanQueue.add(existing[0]!.id);
        this.processQueue();
        return;
      }

      // Create new av_build_checks record
      const record = (await this.pb.collection("av_build_checks").create({
        build: buildId,
        status: "pending",
      })) as AvBuildChecksResponse;
      logger.debug(`Created AV check ${record.id} for build ${buildId}`);
      this.scanQueue.add(record.id);
      this.processQueue();
    } catch (error) {
      logger.error(`Failed to create AV check for build ${buildId}:`, error);
    }
  }

  private async subscribeToNewBuilds() {
    try {
      await this.pb.collection("app_builds").subscribe("*", (data) => {
        if (data.action === "create") {
          const buildId = data.record.id;
          logger.debug("New build received:", buildId);
          // Create AV check for this build
          this.createAvBuildCheck(buildId);
        }
      });

      logger.info("Subscribed to app_builds collection");
    } catch (error) {
      logger.error("Failed to subscribe to app_builds collection:", error);
      throw error;
    }
  }

  private async processQueue() {
    if (this.isProcessing || this.scanQueue.size === 0) return;

    this.isProcessing = true;
    const recordId = this.scanQueue.values().next().value!;
    this.scanQueue.delete(recordId);

    try {
      await this.processBuildCheck(recordId);
    } catch (error) {
      logger.error(`Failed to process check ${recordId}:`, error);
      // Requeue with delay? For now, just log
    } finally {
      this.isProcessing = false;
      // Process next item if any
      setTimeout(() => this.processQueue(), 0);
    }
  }

  private async processBuildCheck(recordId: string) {
    logger.info(`Processing build check: ${recordId}`);

    // Update status to scanning
    await this.pb.collection("av_build_checks").update(recordId, {
      status: "scanning",
      scan_time: new Date().toISOString(),
    });

    let checkRecord: AvBuildChecksResponse<{ build: AppBuildsResponse }>;
    let buildRecord: AppBuildsResponse;

    try {
      checkRecord = (await this.pb
        .collection("av_build_checks")
        .getOne(recordId, {
          expand: "build",
        })) as AvBuildChecksResponse<{ build: AppBuildsResponse }>;

      if (!checkRecord.expand?.build) {
        throw new Error(`Build not found for check ${recordId}`);
      }

      buildRecord = checkRecord.expand.build;
    } catch (error) {
      await this.markAsError(recordId, `Failed to fetch records: ${error}`);
      return;
    }

    if (!buildRecord.files || buildRecord.files.length === 0) {
      await this.markAsClean(recordId, "No files to scan");
      return;
    }

    let infectedFound = false;
    let virusName = "";
    let scanLog = "";

    for (const fileName of buildRecord.files) {
      try {
        const result = await this.scanBuildFile(buildRecord.id, fileName);
        scanLog += `File: ${fileName}\n${result.log}\n\n`;

        if (result.infected) {
          infectedFound = true;
          virusName = result.virusName;
          // First infection wins
          break;
        }
      } catch (error) {
        scanLog += `File: ${fileName}\nERROR: ${error}\n\n`;
        await this.markAsError(
          recordId,
          `File scan failed: ${error}\n\n${scanLog}`,
        );
        return;
      }
    }

    // Clean up downloaded files
    await this.cleanupBuildFiles(buildRecord.id);

    if (infectedFound) {
      await this.markAsInfected(recordId, virusName, scanLog);
    } else {
      await this.markAsClean(recordId, scanLog);
    }
  }

  private async scanBuildFile(
    buildId: string,
    fileName: string,
  ): Promise<ScanResult> {
    const fileUrl = this.pb.files.getUrl(
      { id: buildId, collectionId: "app_builds" },
      fileName,
    );
    const localPath = `${WORK_DIR}/${buildId}_${fileName.replace(/[^a-zA-Z0-9._-]/g, "_")}`;

    // Download file with retries
    for (let attempt = 1; attempt <= this.maxRetries; attempt++) {
      try {
        const response = await fetch(fileUrl);
        if (!response.ok) throw new Error(`HTTP ${response.status}`);

        const arrayBuffer = await response.arrayBuffer();
        await Bun.write(localPath, arrayBuffer);
        break;
      } catch (error) {
        if (attempt === this.maxRetries) {
          throw new Error(
            `Download failed after ${this.maxRetries} attempts: ${error}`,
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

  private async cleanupBuildFiles(buildId: string) {
    try {
      const files = await $`ls ${WORK_DIR}/${buildId}_* 2>/dev/null || true`;
      for (const file of files.text().split("\n").filter(Boolean)) {
        await $`rm -f ${file}`;
      }
    } catch (error) {
      logger.warn(`Failed to cleanup files for build ${buildId}:`, error);
    }
  }

  private async markAsClean(recordId: string, log: string) {
    await this.pb.collection("av_build_checks").update(recordId, {
      status: "clean",
      scan_time: new Date().toISOString(),
      log: log.slice(0, 1000), // Limit log size
    });
    logger.info(`Build check ${recordId} marked as clean`);
  }

  private async markAsInfected(
    recordId: string,
    virusName: string,
    log: string,
  ) {
    await this.pb.collection("av_build_checks").update(recordId, {
      status: "infected",
      virus_name: virusName,
      scan_time: new Date().toISOString(),
      log: log.slice(0, 1000),
    });
    logger.warn(`Build check ${recordId} marked as infected: ${virusName}`);
  }

  private async markAsError(recordId: string, log: string) {
    await this.pb.collection("av_build_checks").update(recordId, {
      status: "error",
      scan_time: new Date().toISOString(),
      log: log.slice(0, 1000),
    });
    logger.error(`Build check ${recordId} marked as error`);
  }
}

// Handle graceful shutdown
process.on("SIGINT", () => {
  logger.info("Shutting down...");
  process.exit(0);
});

process.on("SIGTERM", () => {
  logger.info("Terminating...");
  process.exit(0);
});

// Start scanner
const scanner = new AVScanner();
scanner.start().catch((error) => {
  logger.error("Unhandled error in scanner:", error);
  process.exit(1);
});
