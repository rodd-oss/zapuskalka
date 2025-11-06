import './assets/main.css'

import { createApp } from 'vue'
import App from './App.vue'
import AuthPage from './pages/AuthPage.vue'
import HomePage from './pages/HomePage.vue'

import { createMemoryHistory, createRouter } from 'vue-router'
import { useAuth } from './lib/usePocketbase'
import StorePage from './pages/StorePage.vue'
import LibraryPage from './pages/LibraryPage.vue'

export const router = createRouter({
  history: createMemoryHistory(),
  routes: [
    { path: '/', component: HomePage },
    { path: '/auth', component: AuthPage },
    { path: '/store', component: StorePage },
    { path: '/library', component: LibraryPage },
  ],
})

router.beforeEach(async (to, from) => {
  const auth = useAuth()
  if (!auth.isValid.value && to.path !== '/auth') {
    return { path: '/auth' }
  }
})

createApp(App).use(router).mount('#app')
