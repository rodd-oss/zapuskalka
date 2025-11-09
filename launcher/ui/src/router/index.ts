import { createRouter, createWebHashHistory } from 'vue-router'
import { useAuth } from '@/lib/usePocketbase'
import HomePage from '@/pages/HomePage.vue'
import AuthPage from '@/pages/AuthPage.vue'
import StorePage from '@/pages/StorePage.vue'
import LibraryPage from '@/pages/LibraryPage.vue'
import LibraryGamePage from '@/pages/LibraryGamePage.vue'

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

router.beforeEach(async (to) => {
  const auth = useAuth()
  if (!auth.isValid.value && to.path !== '/auth') {
    return { path: '/auth' }
  }
})

export default router
