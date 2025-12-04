import { createRouter, createWebHistory } from 'vue-router'
import type { RouteLocationNormalized } from 'vue-router'
import Home from '@pages/HomePage.vue'
import Login from '@pages/auth/LoginPage.vue'
import OAuthCallback from '@pages/auth/OAuthCallbackPage.vue'
import { useAuthStore } from '@stores/auth'

declare module 'vue-router' {
  interface RouteMeta {
    requiresAuth?: boolean
    guestOnly?: boolean
  }
}

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/',
      name: 'home',
      component: Home,
    },
    {
      path: '/cabinet',
      name: 'cabinet',
      component: () => import('@pages/CabinetPage.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/auth',
      redirect: { name: 'login' },
      children: [
        {
          path: 'login',
          name: 'login',
          component: Login,
        },
        {
          path: 'oauth-callback',
          name: 'oauth-callback',
          component: OAuthCallback,
          props: (route) => ({
            code: route.query.code || '',
            scope: route.query.scope || '',
            state: route.query.state || '',
          }),
        },
        {
          path: 'app',
          name: 'app-auth',
          component: Login,
          props: { isApp: true },
        }
      ],
    },
  ],
})

router.beforeEach(async (to: RouteLocationNormalized) => {
  if (to.meta.requiresAuth) {
    const authStore = useAuthStore()
    if (!authStore.isAuthenticated) {
      return {
        name: 'login',
        query: { redirect: to.fullPath },
      }
    }
  }

  return true
})

export default router
