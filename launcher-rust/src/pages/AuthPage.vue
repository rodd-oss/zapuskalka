<script setup lang="ts">
import { ref } from 'vue'
import { cn } from '@/lib/utils'
import { useAuth } from '@/lib/usePocketbase'
import { useRouter } from 'vue-router'
import type { AuthMethodsList } from 'pocketbase'
// import Input from '@/components/ui/Input.vue'

const auth = useAuth()
const router = useRouter()

// TODO: Implement OTP with email
// const email = ref('')
const authMethods = ref<AuthMethodsList>()

auth.listAuthMethods().then((methods) => (authMethods.value = methods))

const onLoginWithOAuth = async (provider: string) => {
  await auth.authWithOAuth2(provider)
  router.push('/')
}
</script>

<template>
  <div class="flex h-screen w-full items-center justify-center px-4">
    <div :class="cn('flex min-w-80 flex-col gap-6')">
      <div class="min-h-80">
        <h1 class="w-full text-center text-3xl">Zapuskalka</h1>
        <div class="flex flex-col gap-6">
          <div class="flex flex-col gap-3">
            <template v-if="authMethods && authMethods.oauth2.enabled">
              <button
                type="button"
                variant="outline"
                class="w-full"
                v-for="provider in authMethods.oauth2.providers"
                :key="provider.name"
                :disabled="auth.loading.value"
                @click="onLoginWithOAuth(provider.name)"
              >
                Login with {{ provider.displayName }}
              </button>
            </template>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
