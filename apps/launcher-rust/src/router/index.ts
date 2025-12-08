import { createRouter, createWebHashHistory, type RouteLocationNormalizedGeneric } from 'vue-router'
import { useAuth } from '@/lib/usePocketbase'
// import HomePage from '@/pages/HomePage.vue'
import AuthPage from '@/pages/AuthPage.vue'
import LibraryPage from '@/pages/LibraryPage.vue'
import LibraryGamePage from '@/pages/LibraryGamePage.vue'
import SettingsPage from '@/pages/SettingsPage.vue'
import SettingsAccountPage from '@/pages/SettingsAccountPage.vue'
import SettingsStoragePage from '@/pages/SettingsStoragePage.vue'

import { getCurrentWindow } from '@tauri-apps/api/window'

export const router = createRouter({
  history: createWebHashHistory(),
  routes: [
    { path: '/', redirect: '/library' },
    { path: '/auth', component: AuthPage, name: 'Authentication' },
    {
      path: '/settings',
      component: SettingsPage,
      children: [
        { path: '', redirect: '/settings/account', name: 'Settings' },
        { path: 'account', component: SettingsAccountPage, name: 'Settings - Account' },
        { path: 'storage', component: SettingsStoragePage, name: 'Settings - Storage' },
      ],
    },
    {
      path: '/library',
      component: LibraryPage,
      children: [{ path: ':id', component: LibraryGamePage }],
      name: 'Library',
    },
  ],
})

router.beforeEach(async (to) => {
  const auth = useAuth()
  if (!auth.isValid.value && to.path !== '/auth') {
    return { path: '/auth' }
  }

  if (auth.isValid.value && to.path === '/auth') {
    return { path: '/' }
  }
})

router.afterEach(async (to) => {
  await getCurrentWindow().setTitle(titleBuilder(to))
})

const title = 'Zapuskalka'
function titleBuilder(to: RouteLocationNormalizedGeneric) {
  if (to.path === '/') {
    return title
  }

  if (to.name === undefined) {
    return title
  }

  return `${title} | ${to.name.toString()}`
}

export default router
