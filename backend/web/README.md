# Zapuskalka Web Frontend

A modern, type-safe web frontend built with Vue 3, TypeScript, and Tailwind CSS. This project provides a responsive user interface for the Zapuskalka gaming platform.

## Table of Contents

- [Overview](#overview)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [Available Commands](#available-commands)
- [Development Workflow](#development-workflow)
- [Project Configuration](#project-configuration)
- [Code Quality](#code-quality)

## Overview

This is a Vue 3 application built with the Composition API, providing a modern, reactive user interface with:

- **Type Safety**: Full TypeScript support for development and runtime safety
- **Fast Development**: Vite provides instant HMR (Hot Module Replacement) for seamless development
- **Modern Styling**: Tailwind CSS for utility-first, responsive design
- **State Management**: Pinia for predictable, type-safe application state
- **Authentication**: Integrated with PocketBase for secure user authentication

## Tech Stack

### Core

- **Language**: [`TypeScript`](https://www.typescriptlang.org/) - Type-safe JavaScript
- **Runtime**: [`Bun`](https://bun.com/) - Fast JavaScript runtime and package manager
- **Package Manager**: [`Bun`](https://bun.com/) - All-in-one JavaScript toolchain

### Build & Development

- **Build Tool**: [`Vite`](https://vite.dev/) - Next-generation frontend build tool
- **Framework**: [`Vue`](https://vuejs.org/) 3 with Composition API - Progressive JavaScript framework

### Routing & State Management

- **Router**: [`Vue Router`](https://router.vuejs.org/) - Official Vue routing solution
- **State Manager**: [`Pinia`](https://pinia.vuejs.org/) - Intuitive, type-safe state management

### Styling

- **CSS**: [`Tailwind CSS`](https://tailwindcss.com/) - Utility-first CSS framework
- **UI Library**: [`Nuxt UI`](https://ui.nuxt.com/) - Official UI component library

> [!WARNING]
> Nuxt UI is being used temporarily until a dedicated user interface library is developed.

### Misc

- **PocketBase**: [`JavaScript SDK`](https://github.com/pocketbase/js-sdk) - Official JavaScript SDK for interacting with the PocketBase API.
- **Validation**: [`Zod`](https://zod.dev/) - TypeScript-first schema validation

### Code Quality

- **Linter**: [`ESLint`](https://eslint.org/) - JavaScript linting utility
- **Formatter**: [`Prettier`](https://prettier.io/) - Code formatter

## Project Structure

```
src/
├── pages/                 # Route components
├── components/            # Reusable Vue components
├── router/                # Vue Router configuration
├── stores/                # Pinia stores
├── lib/                   # Shared libraries and utilities
├── types/                 # TypeScript type definitions
├── providers/             # Vue providers (e.g., AuthProvider)
├── assets/                # Global styles
├── App.vue                # Root component
└── main.ts                # Application entry point
```

## Getting Started

### Prerequisites

- **Bun** - [Install Bun](https://bun.sh/)
- **Node.js** (optional, for compatibility)

### Installation

Install dependencies:

```bash
bun install
```

### Running the Application

Start the development server:

```bash
bun run dev
```

The application will be available at `http://localhost:5173/`

**Development Tools**: Vue DevTools are also available

## Available Commands

### Development

```bash
bun run dev
```

Starts the Vite development server with hot module replacement (HMR). The application will automatically reload when you make changes.

### Build for Production

```bash
bun run build
```

Creates an optimized production build in the `dist/` directory. The build process includes:

- TypeScript compilation
- Code minification
- CSS optimization
- Asset optimization

### Preview Production Build

```bash
bun run preview
```

Serves the production build locally for testing before deployment.

### Linting

```bash
bun run lint
```

Runs ESLint to check code quality and style consistency.

### Formatting

```bash
bun run format
```

Runs Prettier to format code according to project standards.

## Development Workflow

### Creating a New Page

1. Create a new Vue component in `src/pages/`:

   ```vue
   <template>
     <div>
       <!-- Page content -->
     </div>
   </template>

   <script setup lang="ts">
   // Component logic here
   </script>
   ```

2. Register the route in `src/router/index.ts`

### Working with State

Use Pinia stores for application state:

```typescript
// stores/yourStore.ts
import { defineStore } from 'pinia'
import { ref } from 'vue'

export const useYourStore = defineStore('your-store', () => {
  const state = ref('initial value')

  return { state }
})
```

### Authentication

The app includes authentication via PocketBase. Use the `AuthProvider.vue` component and `useAuthStore()` from the auth store.

## Project Configuration

### TypeScript Configuration

- **tsconfig.json** - Base configuration
- **tsconfig.app.json** - App-specific settings
- **tsconfig.node.json** - Build tools configuration

### Vite Configuration

See `vite.config.ts` for:

- Plugin configuration
- Build optimization
- Development server settings

### Auto-imports

Component auto-imports are configured via `auto-imports.d.ts` and `components.d.ts`

## Code Quality

### ESLint

The project uses ESLint for code consistency. Configuration is in `eslint.config.ts`.

### Prettier

Code formatting follows Prettier standards. Integrate it with your editor for automatic formatting on save.

### Type Safety

Full TypeScript support ensures:

- Compile-time type checking
- Better IDE autocomplete
- Reduced runtime errors
