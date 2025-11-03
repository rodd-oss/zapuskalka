<script setup lang="ts">
import LoginForm from '@/components/LoginForm.vue'
import { Button } from '@/components/ui/button'
import { useAuth } from '@/lib/usePocketbase'

const auth = useAuth()
</script>

<template>
  <div class="flex h-screen w-full items-center justify-center px-4">
    <div v-if="auth.isValid.value">
      Hi {{ auth.record.value?.name }}
      <Button @click="auth.logout">Log out</Button>
    </div>
    <LoginForm v-else @submit="auth.authUserWithPassword" @oauth="auth.authWithOAuth2" />
  </div>
</template>
