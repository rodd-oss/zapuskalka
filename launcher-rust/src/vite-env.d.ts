/// <reference types="vite/client" />

declare module '*.vue' {
  import type { DefineComponent } from 'vue'
  const component: DefineComponent<{}, {}, any>
  export default component
}

interface ImportMetaEnv {
  readonly VITE_BACKEND_URL: string
  readonly VITE_SENTRY_DSN: string
  // more env variables...
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
