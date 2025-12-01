<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useAuthStore } from '@/stores/auth'

const authStore = useAuthStore()
const isInitialized = ref(false)

onMounted(async () => {
  await authStore.getAuthMethods()
  await authStore.refreshAuth()

  isInitialized.value = true
})
</script>

<template>
  <slot v-if="isInitialized" />
  <div v-else class="flex items-center justify-center min-h-screen">
    <UIcon name="i-lucide-loader-2" class="w-8 h-8 animate-spin text-primary" />
  </div>
</template>
