<script setup lang="ts">
import type { ButtonProps } from '@nuxt/ui'
import { computed, onMounted, ref } from 'vue'
import usePocketBase from '../lib/usePocketbase'

const pb = usePocketBase()

const authMethods = ref<Awaited<ReturnType<typeof pb.collection<'users'>>>['listAuthMethods'] extends () => Promise<infer R> ? R : never>()
const isLoading = ref(true)
const error = ref<Error | null>(null)

const providers = computed<ButtonProps[]>(() => {
  if (!authMethods.value?.oauth2?.enabled) {
    return []
  }

  return authMethods.value.oauth2.providers.map((provider) => ({
    label: `Continue with ${provider.name}`,
    icon: `i-simple-icons:${provider.name.toLowerCase()}`,
    to: `${provider.authURL}http://localhost:8090/oauth/${provider.name}/callback`,
    onClick: () => {
      localStorage.setItem('provider', JSON.stringify(provider))
    },
  }))
})

onMounted(async () => {
  try {
    authMethods.value = await pb.collection('users').listAuthMethods()
  } catch (e) {
    error.value = e instanceof Error ? e : new Error('Failed to load auth methods')
  } finally {
    isLoading.value = false
  }
})
</script>
<template>
  <UMain>
    <div class="flex min-h-svh w-full items-center justify-center p-6 md:p-10">
      <UPageCard class="w-full max-w-md">
        <template v-if="isLoading">
          <div class="flex justify-center p-4">
            <UIcon name="i-lucide-loader-2" class="animate-spin" />
          </div>
        </template>

        <template v-else-if="error">
          <div class="text-red-500 p-4 text-center">
            {{ error.message }}
          </div>
        </template>

        <template v-else>
          <UAuthForm
            title="Login"
            icon="i-lucide-user"
            :providers="providers"
          />
        </template>
      </UPageCard>
    </div>
  </UMain>
</template>
