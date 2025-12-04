<script setup lang="ts">
import { cn } from '@/lib/utils'
import { useAuth, usePocketBase } from '@/lib/usePocketbase'
import { useRouter } from 'vue-router'
import { openUrl } from '@tauri-apps/plugin-opener'
import { onOpenUrl } from '@tauri-apps/plugin-deep-link'
import type { AuthRecord, AuthMethodsList } from 'backend-api'
import { ref } from 'vue'

const router = useRouter()
const pb = usePocketBase()
const auth = useAuth()

const authMethods = ref<AuthMethodsList>()

const isDev = ref(import.meta.env.DEV)

auth.listAuthMethods().then((methods) => (authMethods.value = methods))

const onLoginWithOAuth = async (provider: string) => {
  await auth.authWithOAuth2(provider)
  router.push('/')
}

const AuthWithBrowser = async () => {
  await openUrl(`${import.meta.env.VITE_FRONTEND_URL || 'http://localhost:8090'}/auth/app`)
  const unlist = await onOpenUrl(async (urls) => {
    urls.forEach(async (url) => {
      const urlObj = new URL(url)
      const token = urlObj.searchParams.get('token')
      if (token) {
        const data = await pb.send<{ record: AuthRecord, token: string }>('/api/get-app-token', {
          method: 'POST',
          body: { token },
        })
        pb.authStore.save(data.token, data.record)
        unlist()
        router.push('/')
      }
    })
  })
}
</script>

<template>
  <div class="flex h-screen w-full items-center justify-center px-4">
    <div :class="cn('flex min-h-80 min-w-80 flex-col gap-6')">
      <h1 class="w-full text-center text-3xl">Запускалка</h1>
      <div class="flex flex-col gap-6">
        <div class="flex flex-col gap-3">
          <template v-if="authMethods && isDev">
            <button
              class="cursor-pointer rounded border p-2 hover:bg-gray-100 disabled:cursor-not-allowed disabled:opacity-50"
              type="button" v-for="provider in authMethods.oauth2.providers" :key="provider.name"
              :disabled="auth.loading.value" @click="onLoginWithOAuth(provider.name)">
              Login with {{ provider.displayName }}
            </button>
          </template>

          <button
            class="cursor-pointer rounded border p-2 hover:bg-gray-100 disabled:cursor-not-allowed disabled:opacity-50"
            type="button" @click="AuthWithBrowser">
            Auth with browser
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
