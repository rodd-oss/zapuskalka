#!/usr/bin/env bun

import { join } from "path";

interface TauriConfig {
  version: string;
  bundle?: {
    createUpdaterArtifacts?: boolean;
    [key: string]: unknown;
  };
  plugins?: {
    updater?: unknown;
    [key: string]: unknown;
  };
  [key: string]: unknown;
}

async function prepareCiConfig() {
  const rootDir = join(import.meta.dir, "..");
  const tauriConfPath = join(rootDir, "launcher-rust", "src-tauri", "tauri.conf.json");

  const file = Bun.file(tauriConfPath);
  const config = (await file.json()) as TauriConfig;

  if (config.bundle) {
    config.bundle.createUpdaterArtifacts = false;
  }

  delete config.plugins;

  await Bun.write(tauriConfPath, JSON.stringify(config, null, 2) + "\n");
  console.log("Prepare tauri.conf.json for CI");
}

prepareCiConfig().catch((error) => {
  console.error("Error with prepare config for CI:", error);
  process.exit(1);
});

