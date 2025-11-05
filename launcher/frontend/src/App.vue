<script setup lang="ts">
import { ref } from 'vue';
import Auth from './pages/AuthPage.vue';
import Home from './pages/HomePage.vue';

const isAuthenticated = ref(false);
</script>

<template>
  <Auth v-if="!isAuthenticated" />
  <Home v-else />
</template>

<style scoped>
</style>
