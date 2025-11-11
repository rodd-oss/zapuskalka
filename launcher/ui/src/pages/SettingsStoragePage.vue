<script setup lang="ts">
import { useAuthenticated } from '@/lib/usePocketbase'
import Button from 'primevue/button'
import { onMounted } from 'vue'
import { ref } from 'vue'

useAuthenticated()

interface Storage {
  title: string
  path: string
}

const storageList = ref<Storage[]>([
  { title: 'ДИСК Д', path: 'D://games' },
  { title: 'ОСНОВНОЙ', path: 'С://Program Files/Zapuskalka/apps' },
])

onMounted(() => {
  // const storageList.value = await loadStorageList() - go binding
})

const createStorageHandler = async () => {
  // const path: string = await osOpenFolder()
  // storageList.value.push({ path, title: `Storage_${storageList.value.length + 1}` })
  // await saveStorageList(storages.value)  - go binding
}
</script>
<template>
  <div>SETTINGS STORAGE</div>
  <div v-for="storage in storageList" :key="storage.path">
    <span>{{ storage.title }}</span>
    <span>{{ storage.path }}</span>
    <Button>Delete</Button>
  </div>
</template>
<style scoped></style>
