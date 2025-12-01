<script setup lang="ts">
import { open } from '@tauri-apps/plugin-dialog'
import { ref } from 'vue'

const error = ref<string | undefined>()
const model = defineModel<string>()

const selectFolder = async () => {
  error.value = undefined
  try {
    const appRootFolder = await open({
      title: 'Select folder with your exported app',
      multiple: false,
      directory: true,
    })

    if (appRootFolder == null) {
      model.value = undefined
      return
    }

    model.value = appRootFolder
  } catch (err) {
    if (err instanceof Error) {
      error.value = err.message
    } else if (err instanceof String) {
      error.value = err.toString()
    } else if (typeof err == 'string') {
      error.value = err
    } else {
      error.value = 'Unknown error occurred'
    }

    console.error('Select folder error:', err)
  }
}
</script>

<template>
  <div>
    <label
      for="browse-buttom-id"
      class="block text-xs font-medium text-gray-700 dark:text-gray-300"
    >
      Folder
    </label>
    <button
      id="browse-buttom-id"
      class="w-full cursor-pointer rounded-md border-2 border-dashed border-gray-400 p-2 text-gray-500 hover:border-gray-300 disabled:cursor-not-allowed disabled:opacity-50 dark:text-gray-400"
      @click="selectFolder"
      type="button"
    >
      <span v-if="model">Selected folder: {{ model }}</span>
      <span v-else>Select folder with your exported app</span>
    </button>
    <span class="text-red-500">{{ error }}</span>
  </div>
</template>
