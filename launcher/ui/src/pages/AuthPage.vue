<script setup lang="ts">
import { ref } from 'vue'
import { cn } from '@/lib/utils'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
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
      <Card class="min-h-80">
        <CardHeader>
          <CardTitle>Login to your account</CardTitle>
          <CardDescription> Enter your email below to login to your account </CardDescription>
        </CardHeader>
        <CardContent>
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
                <Input
                  id="password"
                  type="password"
                  required
                  v-model="password"
                  :disabled="auth.loading.value"
                />
              </div>
              <div class="flex flex-col gap-3">
                <Button type="submit" class="w-full" :disabled="auth.loading.value"> Login </Button>
                <template v-if="authMethods && authMethods.oauth2.enabled">
                  <Button
                    type="button"
                    variant="outline"
                    class="w-full"
                    v-for="provider in authMethods.oauth2.providers"
                    :key="provider.name"
                    :disabled="auth.loading.value"
                    @click="onLoginWithOAuth(provider.name)"
                  >
                    Login with {{ provider.displayName }}
                  </Button>
                </template>
              </div>
            </div>
            <div class="mt-4 text-center text-sm">
              Don't have an account?
              <a href="#" class="underline underline-offset-4"> Sign up </a>
            </div>
          </form>
        </CardContent>
      </Card>
    </div>
  </div>
</template>
