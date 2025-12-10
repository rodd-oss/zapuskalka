# AGENTS.md

Instructions for agentic coding assistants operating in this repository.

After making changes, run lint and typecheck commands for the affected project.

## Build Commands

**Frontend (Vue):** `bun run dev`, `build`, `check`, `lint`, `format`. `check:lsp` (type-check), `check:lint`, `check:format`.
**Launcher (Tauri/Rust):** `bun run tauri dev`, `tauri build`, `check`, `format` (Prettier + Tailwind plugin).
**Backend (Go):** `task build-backend`, `dev-backend`, `go build ./...`, `go fmt ./...`, `go vet ./...`.
**Launcher Core (Rust):** `cargo check --all-targets`, `cargo clippy --all-targets -- -D warnings`, `cargo fmt --all -- --check`.
**All Projects:** `task build`, `task dev`.

## Testing

**Frontend:** No test framework yet. When added: `bun test` (all), `bun test path/to/test.spec.ts` (single).
**Backend:** `go test ./...` (all), `go test ./path/to/package` (package).
**Launcher Core:** `cargo test` (all), `cargo test test_name` (single).

## Code Style Guidelines

**Formatting:** No semicolons, single quotes, 100 char width (Prettier). Go: `gofmt`.
**TypeScript:** Strict mode, no non-null assertions (`@typescript-eslint/no-non-null-assertion`).
**Vue:** `<script setup lang="ts">` with explicit imports. PascalCase component names.
**Naming:** PascalCase components, camelCase variables/functions, SCREAMING_SNAKE_CASE constants.
**Error Handling:** try/catch with proper logging. Avoid silent failures.
**Imports:** External libs first, internal modules with `@/` prefix. Aliases: `@/`, `@pages`, `@components`, `@stores`, `@lib`.
**Tailwind:** Use Tailwind CSS with `prettier-plugin-tailwindcss` sorting.
**Go:** `go fmt`, `go vet`. Standard Go naming conventions.
**Rust:** `cargo fmt`, `clippy`. Rust naming conventions (snake_case).