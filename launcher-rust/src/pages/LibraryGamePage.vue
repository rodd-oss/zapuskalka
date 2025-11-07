<script setup lang="ts">
import Button from '@/components/ui/button/Button.vue'
import { useAuthenticated } from '@/lib/usePocketbase'

useAuthenticated()
</script>
<template>
  <div class="flex flex-col gap-4 p-4">
    <h1 class="text-6xl">{{ $route.params.id }}</h1>
    <Button size="lg">ZAPUSK</Button>
  </div>
</template>
<style scoped></style>
