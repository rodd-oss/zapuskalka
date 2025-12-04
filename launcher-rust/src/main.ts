import './assets/main.css'
import { createApp } from 'vue'
import App from './App.vue'
import DevApp from './DevApp.vue'
import router from './router'
import { createPinia } from 'pinia'
import * as Sentry from '@sentry/vue'
import { createSentryPiniaPlugin } from '@sentry/vue'

const app = createApp(import.meta.env.DEV ? DevApp : App)

Sentry.init({
  app,
  dsn: import.meta.env.VITE_SENTRY_DSN,
  integrations: [Sentry.browserTracingIntegration({ router })],
  enableLogs: true,
  environment: import.meta.env.PROD ? 'production' : 'development',
  tracesSampleRate: 0.01,
  enabled: import.meta.env.PROD,
})

const pinia = createPinia()
pinia.use(createSentryPiniaPlugin())

app.use(pinia)
app.use(router)

app.mount('#app')
