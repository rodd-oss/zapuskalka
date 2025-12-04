<script setup lang="ts">
import { useAuthStore } from '@stores/auth'
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'

const OAUTH_STORAGE_KEY = 'oauth2'
const SUCCESS_REDIRECT_DELAY_MS = 2000

const props = defineProps<{
  code?: string
  scope?: string
  state?: string
}>()

const auth = useAuthStore()
const router = useRouter()
const isLoading = ref(true)
const error = ref<string | null>(null)
const appDeepLink = ref<string | null>(null)

function clearOAuthStorage(): void {
  localStorage.removeItem(OAUTH_STORAGE_KEY)
}

onMounted(async () => {
  const oauthDataJson = localStorage.getItem(OAUTH_STORAGE_KEY)

  if (!oauthDataJson) {
    error.value = 'OAuth session data not found. Please try logging in again.'
    isLoading.value = false
    return
  }

  const oauth = JSON.parse(oauthDataJson) as {
    provider: {
      name: string
      state: string
      codeVerifier: string
    }
    isApp: boolean
  }

  if (!oauth) {
    error.value = 'Invalid OAuth session data. Please try logging in again.'
    clearOAuthStorage()
    isLoading.value = false
    return
  }

  if (oauth.provider.state !== props.state) {
    error.value = 'Invalid state parameter. This may be a security issue.'
    clearOAuthStorage()
    isLoading.value = false
    return
  }

  if (!props.code) {
    error.value = 'Authorization code not provided by the OAuth provider.'
    clearOAuthStorage()
    isLoading.value = false
    return
  }

  const redirectUri = `${window.location.origin}/auth/oauth-callback`

  try {
    const success = await auth.authenticateWithOAuth2Code(
      oauth.provider.name,
      props.code,
      oauth.provider.codeVerifier,
      redirectUri,
    )

    clearOAuthStorage()

    if (!success) {
      error.value = auth.error || 'Authentication failed. Please try again.'
      return
    }

    if (oauth.isApp) {
      const token = await auth.genAuthToken()
      appDeepLink.value = `zapuskalka://auth?token=${token}`
      window.location.href = appDeepLink.value
    } else {
      setTimeout(() => {
        router.push('/')
      }, SUCCESS_REDIRECT_DELAY_MS)
    }
  } catch (err) {
    clearOAuthStorage()
    error.value = err instanceof Error ? err.message : 'Authentication failed. Please try again.'
  } finally {
    isLoading.value = false
  }
})
</script>

<template>
  <div class="min-h-screen flex items-center justify-center px-4">
    <UPageCard class="w-full max-w-md">
      <template v-if="isLoading">
        <div class="flex items-center justify-center py-8">
          <UIcon name="i-lucide-loader-2" class="h-8 w-8 animate-spin text-primary" />
          <span class="ml-2">Authenticating...</span>
        </div>
      </template>

      <template v-else-if="error">
        <div class="text-center text-red-500">
          <UIcon name="i-lucide-alert-circle" class="h-8 w-8 mx-auto mb-2" />
          <p>{{ error }}</p>
          <UButton class="mt-4" variant="outline" to="/auth/login"> Back to Login </UButton>
        </div>
      </template>

      <template v-else>
        <div class="text-center text-green-500">
          <UIcon name="i-lucide-check-circle" class="h-8 w-8 mx-auto mb-2" />
          <p>Successfully authenticated!</p>
          <p v-if="!appDeepLink" class="text-sm text-muted mt-1">Redirecting...</p>
          <UButton v-if="appDeepLink" class="mt-4" color="primary" :to="appDeepLink">
            Open App
          </UButton>
        </div>
      </template>
    </UPageCard>
  </div>
</template>
