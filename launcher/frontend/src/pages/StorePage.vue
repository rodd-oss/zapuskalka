<script setup lang="ts">
import Button from '@/components/ui/button/Button.vue'
import BaseLayout from '@/layouts/BaseLayout.vue'
import { useAuth, useAuthenticated } from '@/lib/usePocketbase'
import { useRouter } from 'vue-router'

useAuthenticated()

const router = useRouter()
const auth = useAuth()
const onLogout = async () => {
  await auth.logout()
  router.push('/auth')
}
</script>
<template>
  <BaseLayout>
    <div>STORE</div>
  </BaseLayout>
</template>
<style scoped></style>
