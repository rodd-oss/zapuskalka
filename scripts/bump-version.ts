#!/usr/bin/env bun

import { $ } from "bun";
import { join } from "path";

type VersionPart = "major" | "minor" | "patch";

interface Version {
  major: number;
  minor: number;
  patch: number;
}

function parseVersion(version: string): Version {
  const parts = version.split(".").map(Number);
  if (parts.length !== 3 || parts.some((p) => isNaN(p))) {
    throw new Error(`Invalid version format: ${version}`);
  }
  return {
    major: parts[0]!,
    minor: parts[1]!,
    patch: parts[2]!,
  };
}

function formatVersion(version: Version): string {
  return `${version.major}.${version.minor}.${version.patch}`;
}

function bumpVersion(version: Version, part: VersionPart): Version {
  switch (part) {
    case "major":
      return { major: version.major + 1, minor: 0, patch: 0 };
    case "minor":
      return { major: version.major, minor: version.minor + 1, patch: 0 };
    case "patch":
      return { major: version.major, minor: version.minor, patch: version.patch + 1 };
  }
}

async function updateJsonFile(filePath: string, newVersion: string): Promise<void> {
  const file = Bun.file(filePath);
  const content = await file.json() as { version?: string };
  content.version = newVersion;
  await Bun.write(filePath, JSON.stringify(content, null, 2) + "\n");
  console.log(`Updated ${file.name} to version ${newVersion}`);
}

async function updateTomlFile(filePath: string, newVersion: string): Promise<void> {
  const file = Bun.file(filePath);
  const content = await file.text();
  const updated = content.replace(/^version = ".*"$/m, `version = "${newVersion}"`);
  await Bun.write(filePath, updated);
  console.log(`Updated ${file.name} to version ${newVersion}`);
}

async function main() {
  const part = (process.argv[2] as VersionPart) || "patch";

  if (!["major", "minor", "patch"].includes(part)) {
    console.error(`Invalid version part: ${part}`);
    console.error("Usage: bun run scripts/bump-version.ts [major|minor|patch]");
    process.exit(1);
  }

  const gitStatus = await $`git status --porcelain`.text();
  if (gitStatus.trim()) {
    console.error("Error: Working directory is not clean. Please commit or stash changes first.");
    process.exit(1);
  }

  const rootDir = join(import.meta.dir, "..");
  const tauriConfPath = join(rootDir, "launcher-rust", "src-tauri", "tauri.conf.json");
  const cargoTomlPath = join(rootDir, "launcher-rust", "src-tauri", "Cargo.toml");
  const cargoLockPath = join(rootDir, "launcher-rust", "src-tauri", "Cargo.lock");
  const packageJsonPath = join(rootDir, "launcher-rust", "package.json");

  const tauriConfFile = Bun.file(tauriConfPath);
  const tauriConf = await tauriConfFile.json() as { version: string };
  const currentVersion = parseVersion(tauriConf.version);
  const newVersion = bumpVersion(currentVersion, part);
  const newVersionString = formatVersion(newVersion);

  console.log(`Bumping version from ${formatVersion(currentVersion)} to ${newVersionString} (${part})`);
  console.log("");

  await updateJsonFile(tauriConfPath, newVersionString);
  await updateTomlFile(cargoTomlPath, newVersionString);
  await updateTomlFile(cargoLockPath, newVersionString);
  await updateJsonFile(packageJsonPath, newVersionString);

  console.log("");

  const commitMessage = `chore: bump version to ${newVersionString}`;
  await $`git add ${tauriConfPath} ${cargoTomlPath} ${cargoLockPath} ${packageJsonPath}`;
  await $`git commit -m ${commitMessage}`;

  const tagName = `app-v${newVersionString}`;
  await $`git tag -a ${tagName} -m "Release ${newVersionString}"`;

  console.log("");
  console.log(`Created commit: ${commitMessage}`);
  console.log(`Created tag: ${tagName}`);
  console.log("");
}

main().catch((error) => {
  console.error("Error:", error);
  process.exit(1);
});
