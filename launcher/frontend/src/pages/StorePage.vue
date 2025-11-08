<script setup lang="ts">
import BaseLayout from '@/layouts/BaseLayout.vue'
import { useAuthenticated } from '@/lib/usePocketbase'

useAuthenticated()
</script>
<template>
  <BaseLayout>
    <div>STORE</div>
  </BaseLayout>
</template>
<style scoped></style>
