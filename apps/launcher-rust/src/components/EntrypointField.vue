<script setup lang="ts">
import { Field } from '@ark-ui/vue/field'

const model = defineModel<string>({ default: '' })
</script>

<template>
  <Field.Root class="w-full max-w-sm">
    <Field.Label class="text-sm font-medium text-gray-900 dark:text-gray-100">
      Entrypoint
    </Field.Label>
    <Field.Input
      placeholder="game.exe"
      class="mt-1 block w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 placeholder-gray-500 focus:border-gray-900 focus:ring-1 focus:ring-gray-900 focus:outline-hidden dark:border-gray-600 dark:bg-gray-800 dark:text-gray-100 dark:placeholder-gray-400 dark:focus:border-gray-100 dark:focus:ring-gray-100"
      v-model="model"
    />
  </Field.Root>
</template>
