<script setup lang="ts">
import { open } from '@tauri-apps/plugin-dialog'

const selectFolder = async () => {
  const appRootFolder = await open({
    title: 'Select folder with your exported app',
    multiple: false,
    directory: true,
  })
}
</script>
<template>
  <div class="flex w-full flex-col items-center rounded-xl bg-white px-4 py-12 dark:bg-gray-800">
    <label class="flex flex-col gap-2 rounded-xl bg-white px-6 py-4 dark:bg-gray-700">
      Select folder with your exported app
      <button
        class="cursor-pointer rounded bg-emerald-500 p-2 text-amber-50 hover:bg-emerald-400"
        @click="selectFolder"
      >
        Browse
      </button>
    </label>
  </div>
</template>
