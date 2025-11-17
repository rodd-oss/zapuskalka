# Architecture Overview

This document captures how Zapuskalka is structured today and which architectural decisions drive the current MVP scope outlined in `docs/PRODUCT.md`. Keep it up to date as the launcher, backend and distribution model evolve.

## 1. Project Structure

```
/
├── backend/              # PocketBase-powered API, migrations, binaries
│   ├── main.go           # PocketBase bootstrap & plugin hooks
│   ├── migrate-*.go      # Dev/prod helpers to toggle automigrate
│   └── migrations/       # PocketBase schema definitions (e.g., games)
├── launcher/             # Wails desktop client (Go + Vue 3 + Vite)
│   ├── main.go           # Wails bootstrap and runtime bindings
│   ├── app.go            # Application entry, window config
│   └── ui/               # SPA assets bundled into the desktop shell
├── docs/                 # PRD, TRD, etc.
├── scripts/              # Tooling such as `typegen-watcher.ts`
├── Taskfile.yml          # Canonical dev/build tasks (task dev, build-*)
├── package.json          # Root-level tooling dependencies (bun, linting)
└── README.md             # Dev environment setup & workflow
```

## 2. High-Level System Diagram

```
[Player / Developer]
        |
        v
[Wails Desktop Launcher (Vue SPA)]
        |
        v
[PocketBase Backend API] ----> [SQLite (PocketBase data)]
        |
        +----> [S3-compatible Object Storage]  (game builds, media)
        |
        +----> [OAuth Providers: GitHub, Twitch] (planned)
```

- The launcher bundles the Vue SPA inside a Wails desktop shell and talks to PocketBase via the generated `wailsjs` bindings or HTTPS when running outside the shell.
- PocketBase hosts the REST API, authentication, and real-time subscriptions while persisting structured data in SQLite and storing binaries in the configured S3 bucket.
- Future proprietary payment service (Release 3.0) will sit alongside PocketBase and expose a limited API surface once introduced.

## 3. Core Components

### 3.1 Frontend

- **Name:** Zapuskalka Launcher (Wails desktop client)
- **Description:** Cross-platform desktop UI that covers the MVP loop defined in the PRD: account auth, browsing the store, managing the personal library, configuring install locations, monitoring downloads, launching/updating games, and exposing a lightweight developer console for pushing builds.
- **Technologies:** Go (Wails runtime), Vue 3 + Vite + TypeScript, PrimeVue-based??? design system, Tailwind-style utility CSS (via `ui/assets/main.css`), Bun-powered toolchain, PocketBase JS SDK, (generated `wailsjs` bindings).
- **Deployment:** Wails produces native Bundles (`launcher/build/bin/Zapuskalka.*` for macOS and NSIS installer or executable for Windows). Artifacts are distributed to testers along with the PocketBase backend endpoint configuration???.

### 3.2 Backend Services

#### 3.2.1 PocketBase Core API

- **Description:** Single binary service that powers all backend capabilities—auth (email/password, GitHub/Twitch OAuth), collections (games, users, libraries, etc.), file uploads, and real-time updates used by the launcher. Custom logic can be added via PocketBase hooks/plugins.
- **Technologies:** Go 1.22+, PocketBase framework, SQLite (primary DB), S3-compatible storage (in prod, in dev you dont need S3), Taskfile workflows for dev/prod, Docker-ready binary.
- **Deployment:** Packaged PocketBase binary (or Docker image) behind HTTPS (e.g., Caddy or Nginx). `AutoMigrate` is enabled via the build tags (`-tags automigrate`) to protect production data and simplify developer workflow.

#### 3.2.2 Payment / Monetization Service (Planned)

- **Description:** Proprietary microservice responsible for checkout flows (one-off purchases, pay-what-you-want, key distribution) referenced in Release 3.0 of the PRD.
- **Technologies:** TBD (service will expose an API PocketBase can call); isolated repo for licensing reasons.
- **Deployment:** Separate closed-source infrastructure; integrates with PocketBase via REST callbacks/webhooks.

## 4. Data Stores

### 4.1 PocketBase SQLite Database

- **Type:** Embedded SQLite (managed by PocketBase).
- **Purpose:** Primary metadata store for users, authentication tokens, games catalog, library records, storage locations, download jobs, and developer uploads.
- **Key Collections (current MVP):**
  - `_pb_users_auth_` (built-in) — player & developer accounts, hashed passwords, OAuth profiles.
  - `users` - main colection stores user data and info???
  - `games` — lightweight collection that currently tracks title + timestamps; will evolve with additional schema fields (system requirements, media, pricing).
  - Future collections: downloads, storage libraries, purchases, developer organizations (see PRD).

### 4.2 Object Storage

- **Type:** S3-compatible bucket (PocketBase file adapter).
- **Purpose:** Stores uploaded game builds, cover art, screenshots, and launcher assets. In dev, PocketBase keeps files under `backend/pb_data/storage/`; production will swap to S3 by configuring the PocketBase storage adapter.
- **Key Buckets/Prefixes:** `_pb_users_auth_` for avatars (already generated), `games` for binaries/media (to be created).

### 4.3 Local Cache (Launcher)

- **Type:** File-system directories selected by the user ("Libraries").
- **Purpose:** Stores installed game binaries, delta patches, and download caches. Managed entirely by the launcher with metadata.

## 5. External Integrations / APIs

- **S3 / Object Storage:** aws s3 compatiable storage.
- **OAuth Providers:** GitHub & Twitch (planned) for smoother onboarding of developers/players; implemented through PocketBase OAuth provider configuration.
- **Payment Provider:** Proprietary service planned for Release 3.0, accessed over REST from PocketBase.
- **WebView2 (Windows) / System WebView (macOS/Linux):** Pulled by Wails installer to render the Vue app.

## 6. Deployment & Infrastructure

- **Cloud / Hosting:** PocketBase is expected to run on a single VM or container (e.g., Fly.io, Render, or bare-metal VPS). Object storage relies on S3-compatible services (AWS S3, Cloudflare R2, Yandex Cloud, etc.). Launcher is distributed as signed binaries per OS.
- **Key Services:** PocketBase API, S3 bucket, reverse proxy (Caddy/Nginx/Traefik etc.) terminating TLS.
- **CI/CD:** Not yet configured. Local automation provided via `Taskfile.yml` (`task dev`, `task dev-backend`, `task build-osx`, `task build-win`). Future CI should cover linting, type generation (`scripts/typegen-watcher.ts`), launcher builds.
- **Monitoring & Logging:** PocketBase logs to stdout; plan to ship logs to a central collector when deployed.

## 7. Security Considerations

- **Authentication:** PocketBase email/password auth (bcrypt hashes) with GitHub/Twitch OAuth. Launcher stores session tokens securely via Pocketbase-js-sdk utilities.
- **Authorization:** PocketBase collection rules enforce who can read/write games, libraries, and downloads. Admin-only routes remain behind the PocketBase dashboard.
- **Data Encryption:** HTTPS/TLS termination is mandatory for the public API. At rest, SQLite sits on encrypted storage volumes (infrastructure responsibility). S3 buckets should enforce encryption and signed URLs for downloads.
- **Other Practices:** Enabling `AutoMigrate` in dev to auto generate migrations in Pocketbase, input validation in the launcher before sending payloads.

## 8. Development & Testing Environment

- **Local Setup:** Follow `/README.md`.
- **Testing Frameworks:** Not yet established. Frontend can leverage Vitest/Jest + Playwright; backend relies on PocketBase integration tests/migrations. Add linting/formatting via ESLint (`launcher/ui/eslint.config.ts`) and Go fmt/vet.
- **Code Quality Tools:** ESLint for the Vue codebase, TypeScript strict mode, PocketBase migration validation. No automated Go linters configured yet.
- **Environment Parity:** `.env` handling currently manual; Wails ships config via `wails.json`. For backend, environment variables (PORT, storage config) to be wired before production launch.

## 9. Future Considerations / Roadmap

- Release 2.0 per PRD: friends list, chat, advanced download scheduling, file-integrity verification.
- Release 3.0: proprietary payment microservice, developer analytics dashboards, news feeds, flexible pricing (one-off, PWYW) and key management.
- Potential architectural shifts: extract download manager into a separate service for scalability, introduce event-driven messaging for live updates, migrate from single PocketBase instance to managed Postgres + custom Go services once data/traffic demands exceed MVP constraints.

## 10. Project Identification

- **Project Name:** Zapuskalka
- **Repository URL:** https://github.com/rodd-oss/zapuskalka
- **Primary Contact / Team:** Core maintainers @rodd-oss (Milan Rodd) and contributors listed in GitHub.

## 11. Glossary / Acronyms

- **PocketBase:** Embedded Go backend framework that bundles auth, file storage, and real-time APIs on top of SQLite.
- **Wails:** Go framework that embeds a modern web frontend inside native desktop shells for Windows, macOS, and Linux.
- **S3:** Simple Storage Service (or compatible providers) used for storing large game binaries and media assets.
- **PB:** Abbreviation used within the repo for PocketBase artifacts (e.g., `pb_data`, `_pb_users_auth_`).
- **MVP:** Minimum Viable Product as defined in `docs/PRODUCT.md`.
