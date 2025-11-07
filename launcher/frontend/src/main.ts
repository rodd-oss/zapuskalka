import './assets/main.css'

import { createApp } from 'vue'
import App from './App.vue'
import AuthPage from './pages/AuthPage.vue'
import HomePage from './pages/HomePage.vue'

import { createWebHashHistory, createRouter } from 'vue-router'
import { useAuth } from './lib/usePocketbase'
import StorePage from './pages/StorePage.vue'
import LibraryPage from './pages/LibraryPage.vue'
import LibraryGamePage from './pages/LibraryGamePage.vue'

export const router = createRouter({
  history: createWebHashHistory(),
  routes: [
    { path: '/', component: HomePage },
    { path: '/auth', component: AuthPage },
    { path: '/store', component: StorePage },
    {
      path: '/library',
      component: LibraryPage,
      children: [{ path: ':id', component: LibraryGamePage }],
    },
  ],
})

router.beforeEach(async (to, from) => {
  const auth = useAuth()
  if (!auth.isValid.value && to.path !== '/auth') {
    return { path: '/auth' }
  }
})

createApp(App).use(router).mount('#app')
