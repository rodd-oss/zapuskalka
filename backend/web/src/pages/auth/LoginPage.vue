<script setup lang="ts">
import * as z from 'zod'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@stores/auth'
import type { AuthFormField, ButtonProps, FormSubmitEvent } from '@nuxt/ui'
import { computed, onMounted } from 'vue'

const props = defineProps<{
  isApp?: boolean | string
}>()

const router = useRouter()
const auth = useAuthStore()
const toast = useToast()

const isAppMode = computed(() => props.isApp === true || props.isApp === 'true')
const appDeepLink = computed(() => `zapuskalka://auth?token=${auth.token}&user=${JSON.stringify(auth.user)}`)

const fields: AuthFormField[] = [
  {
    name: 'email',
    type: 'email',
    label: 'Email',
    placeholder: 'Enter your email',
    required: true,
  },
  {
    name: 'password',
    label: 'Password',
    type: 'password',
    placeholder: 'Enter your password',
    required: true,
  },
]

const providers = computed<ButtonProps[]>(() => {
  if (auth.authMethods?.oauth2.enabled) {
    return auth.authMethods.oauth2.providers.map<ButtonProps>((provider) => ({
      label: `Continue with ${provider.displayName}`,
      icon: `i-simple-icons:${provider.name.toLowerCase()}`,
      variant: 'outline',
      fullWidth: true,
      to: `${provider.authURL}${window.location.origin}/auth/oauth-callback`,
      onClick: () => {
        localStorage.setItem('oauth2', JSON.stringify({ provider, isApp: isAppMode.value }))
      },
    }))
  }
  return []
})

const schema = z.object({
  email: z.email('Invalid email'),
  password: z.string('Password is required').min(8, 'Must be at least 8 characters'),
})

type Schema = z.output<typeof schema>

async function onSubmit(payload: FormSubmitEvent<Schema>): Promise<void> {
  const success = await auth.login(payload.data.email, payload.data.password)

  if (success) {
    const redirectTo = (router.currentRoute.value.query.redirect as string) || '/'
    router.push(redirectTo)
  } else {
    toast.add({
      title: 'Login Failed',
      description: auth.error || 'An unknown error occurred during login.',
      icon: 'i-lucide-alert-circle',
      color: 'error',
    })
  }
}

onMounted(() => {
  if (auth.isAuthenticated) {
    if (isAppMode.value) {
      window.location.href = appDeepLink.value
    } else {
      router.push('/')
    }
  }
})
</script>

<template>
  <div class="min-h-screen flex items-center justify-center px-4">
    <UPageCard class="w-full max-w-md">
      <template v-if="isAppMode && auth.isAuthenticated">
        <div class="text-center">
          <UButton color="primary" :to="appDeepLink">Open App</UButton>
        </div>
      </template>
      <template v-else>
        <UAuthForm
          title="Sign In"
          :providers="providers"/>
      </template>
    </UPageCard>
  </div>
</template>
