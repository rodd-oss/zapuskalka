<script setup lang="ts">
import Button from './ui/button/Button.vue';


const handleClick = () => {
  console.log('Button clicked')
}

defineProps<{
  msg: string
}>()
</script>

<template>
  <div class="greetings">
    <h1 class="text-2xl text-green-600">{{ msg }}</h1>
    <h3>
      You’ve successfully created a project with
      <a href="https://vite.dev/" target="_blank" rel="noopener">Vite</a> +
      <a href="https://vuejs.org/" target="_blank" rel="noopener">Vue 3</a>.
    </h3>
    <Button @click="handleClick">Click me</Button>
  </div>
</template>

<style scoped>
</style>
