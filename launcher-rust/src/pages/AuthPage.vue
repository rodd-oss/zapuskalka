<script setup lang="ts">
import { ref } from 'vue'
import { cn } from '@/lib/utils'
import { useAuth } from '@/lib/usePocketbase'
import { useRouter } from 'vue-router'
import type { AuthMethodsList } from 'pocketbase'

const auth = useAuth()
const router = useRouter()

const email = ref('')
const password = ref('')
const authMethods = ref<AuthMethodsList>()

auth.listAuthMethods().then((methods) => (authMethods.value = methods))

const onFormSubmit = async () => {
  await auth.authUserWithPassword({ email: email.value, password: password.value })
  router.push('/')
}

const onLoginWithOAuth = async (provider: string) => {
  await auth.authWithOAuth2(provider)
  router.push('/')
}
</script>

<template>
  <div class="flex h-screen w-full items-center justify-center px-4">
    <div :class="cn('flex min-w-80 flex-col gap-6')">
      <div class="min-h-80">
        <div>
          <div>Login to your account</div>
          <div>Enter your email below to login to your account</div>
        </div>
        <div>
          <form @submit.prevent="onFormSubmit">
            <div class="flex flex-col gap-6">
              <div class="grid gap-3">
                <Label for="email">Email</Label>
                <Input
                  id="email"
                  type="email"
                  placeholder="m@example.com"
                  required
                  v-model="email"
                  :disabled="auth.loading.value"
                />
              </div>
              <div class="grid gap-3">
                <div class="flex items-center">
                  <Label for="password">Password</Label>
                  <a
                    href="#"
                    class="ml-auto inline-block text-sm underline-offset-4 hover:underline"
                  >
                    Forgot your password?
                  </a>
                </div>
                <input
                  id="password"
                  type="password"
                  required
                  v-model="password"
                  :disabled="auth.loading.value"
                />
              </div>
              <div class="flex flex-col gap-3">
                <button type="submit" class="w-full" :disabled="auth.loading.value">Login</button>
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
            <div class="mt-4 text-center text-sm">
              Don't have an account?
              <a href="#" class="underline underline-offset-4"> Sign up </a>
            </div>
          </form>
        </div>
      </div>
    </div>
  </div>
</template>
