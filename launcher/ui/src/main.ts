import './assets/main.css'

import { createApp } from 'vue'
import App from './App.vue'
import router from './router'
import { createPinia } from 'pinia'
import ui from '@nuxt/ui/vue-plugin'

const app = createApp(App)
app.use(createPinia())
app.use(router)
app.use(ui)

app.mount('#app')
