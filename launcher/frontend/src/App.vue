<script setup lang="ts">
import { ref } from 'vue'
import Auth from './pages/AuthPage.vue'
import Home from './pages/HomePage.vue'
</script>

<template>
  <h1>Hello App!</h1>
  <p><strong>Current route path:</strong> {{ $route.fullPath }}</p>
  <main>
    <RouterView />
  </main>
</template>

<style scoped></style>
