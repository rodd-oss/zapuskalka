<script setup lang="ts">
import { ref, type HTMLAttributes } from 'vue'
import { cn } from '@/lib/utils'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'

type OAuthProvider = 'twitch' | 'github'

const props = defineProps<{
  class?: HTMLAttributes['class']
}>()

const emit = defineEmits<{
  (e: 'submit', payload: { email: string; password: string }): void
  (e: 'oauth', provider: OAuthProvider): void
}>()

const email = ref('')
const password = ref('')

const onSubmit = () => {
  emit('submit', { email: email.value, password: password.value })
}

const onLoginWithOAuth = (provider: OAuthProvider) => {
  emit('oauth', provider)
}
</script>

<template>
  <div :class="cn('flex flex-col gap-6', props.class)">
    <Card>
      <CardHeader>
        <CardTitle>Login to your account</CardTitle>
        <CardDescription> Enter your email below to login to your account </CardDescription>
      </CardHeader>
      <CardContent>
        <form @submit.prevent="onSubmit">
          <div class="flex flex-col gap-6">
            <div class="grid gap-3">
              <Label for="email">Email</Label>
              <Input id="email" type="email" placeholder="m@example.com" required v-model="email" />
            </div>
            <div class="grid gap-3">
              <div class="flex items-center">
                <Label for="password">Password</Label>
                <a href="#" class="ml-auto inline-block text-sm underline-offset-4 hover:underline">
                  Forgot your password?
                </a>
              </div>
              <Input id="password" type="password" required v-model="password" />
            </div>
            <div class="flex flex-col gap-3">
              <Button type="submit" class="w-full"> Login </Button>
              <Button
                type="button"
                variant="outline"
                class="w-full"
                @click="onLoginWithOAuth('twitch')"
              >
                Login with Twitch
              </Button>
              <Button
                type="button"
                variant="outline"
                class="w-full"
                @click="onLoginWithOAuth('github')"
              >
                Login with GitHub
              </Button>
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
</template>
