# AGENTS.md

## Build Commands

**Frontend (Vue/Nuxt):**
- `bun run dev` - Start dev server
- `bun run build` - Build for production  
- `bun run check` - Run type-check, lint, and format
- `bun run lint` - Lint and fix code
- `bun run format` - Format code with Prettier

**Launcher (Tauri/Rust):**
- `bun run tauri dev` - Start dev server
- `bun run tauri build` - Build desktop app
- `bun run check` - Run type-check, lint, and format

**Backend (Go):**
- `task build-backend` - Build backend
- `task dev-backend` - Run with automigrate

**All Projects:**
- `task build` - Build all components
- `task dev` - Start all dev servers

## Code Style Guidelines

**Formatting:** No semicolons, single quotes, 100 char width (Prettier)
**TypeScript:** Strict mode, no non-null assertions (`@typescript-eslint/no-non-null-assertion`)
**Vue:** Use `<script setup lang="ts">` with explicit imports
**Naming:** PascalCase for components, camelCase for variables/functions
**Error Handling:** Use try/catch with proper error logging
**Imports:** Group external libs first, then internal modules with `@/` prefix