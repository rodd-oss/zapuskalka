import { createRouter, createWebHashHistory } from 'vue-router'
import { useAuth } from '@/lib/usePocketbase'
// import HomePage from '@/pages/HomePage.vue'
import AuthPage from '@/pages/AuthPage.vue'
import LibraryPage from '@/pages/LibraryPage.vue'
import LibraryGamePage from '@/pages/LibraryGamePage.vue'
import SettingsPage from '@/pages/SettingsPage.vue'
import SettingsAccountPage from '@/pages/SettingsAccountPage.vue'
import SettingsStoragePage from '@/pages/SettingsStoragePage.vue'

export const router = createRouter({
  history: createWebHashHistory(),
  routes: [
    { path: '/', redirect: '/library' },
    { path: '/auth', component: AuthPage },
    {
      path: '/settings',
      component: SettingsPage,
      children: [
        { path: '', redirect: '/settings/account' },
        { path: 'account', component: SettingsAccountPage },
        { path: 'storage', component: SettingsStoragePage },
      ],
    },
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
