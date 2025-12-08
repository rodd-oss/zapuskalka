<script setup lang="ts">
import AuthProvider from '@/providers/AuthProvider.vue'
</script>

<template>
  <AuthProvider>
    <UApp>
      <RouterView />
    </UApp>
  </AuthProvider>
</template>
