<script setup lang="ts">
import { ref } from 'vue'
import { cn } from '@/lib/utils'
import { useAuth } from '@/lib/usePocketbase'
// import { useRouter } from 'vue-router'
import type { AuthMethodsList } from 'pocketbase'
import { openUrl } from '@tauri-apps/plugin-opener'
import { onOpenUrl } from '@tauri-apps/plugin-deep-link'

const auth = useAuth()
// const router = useRouter()
// TODO: Implement OTP with email
// const email = ref('')
const authMethods = ref<AuthMethodsList>()

auth.listAuthMethods().then((methods) => (authMethods.value = methods))

// const onLoginWithOAuth = async (provider: string) => {
//   await auth.authWithOAuth2(provider)
//   router.push('/')
// }

const AuthWithBrowser = async () => {
  // throw Error('Not implemented')
  await openUrl(`${import.meta.env.VITE_BACKEND_URL || 'http://localhost:8090'}/auth/login?isApp=true`)
  await onOpenUrl((urls) => {
    console.log('deep link:', urls);
  });
}
</script>

<template>
  <div class="flex h-screen w-full items-center justify-center px-4">
    <div :class="cn('flex min-h-80 min-w-80 flex-col gap-6')">
      <h1 class="w-full text-center text-3xl">Запускалка</h1>
      <div class="flex flex-col gap-6">
        <div class="flex flex-col gap-3">
          <template v-if="authMethods && authMethods.oauth2.enabled">
            <!-- <button
              class="cursor-pointer rounded border p-2 hover:bg-gray-100 disabled:cursor-not-allowed disabled:opacity-50"
              type="button"
              v-for="provider in authMethods.oauth2.providers"
              :key="provider.name"
              :disabled="auth.loading.value"
              @click="onLoginWithOAuth(provider.name)"
            >
              Login with {{ provider.displayName }}
            </button> -->
            <button
              class="cursor-pointer rounded border p-2 hover:bg-gray-100 disabled:cursor-not-allowed disabled:opacity-50"
              type="button" :disabled="auth.loading.value" @click="AuthWithBrowser">
              Auth with browser
            </button>
          </template>
        </div>
      </div>
    </div>
  </div>
</template>
