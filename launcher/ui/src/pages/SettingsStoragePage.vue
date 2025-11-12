<script setup lang="ts">
import { useAuthenticated } from '@/lib/usePocketbase'
import { LoadStorageList, OsOpenFolder, SaveStorageList } from '@/wailsjs/go/main/App'
import type { main } from '@/wailsjs/go/models'
import Accordion from 'primevue/accordion'
import AccordionContent from 'primevue/accordioncontent'
import AccordionHeader from 'primevue/accordionheader'
import AccordionPanel from 'primevue/accordionpanel'
import Button from 'primevue/button'
import { onMounted } from 'vue'
import { ref } from 'vue'

useAuthenticated()

const storageList = ref<main.Storage[]>([])

onMounted(async () => {
  storageList.value = await LoadStorageList()
})

const createStorageHandler = async () => {
  const path: string = await OsOpenFolder()
  if (path.trim() == '') return

  storageList.value.push({ path, title: `Storage_${storageList.value.length + 1}` })
  await SaveStorageList(storageList.value)
}

const deleteStorageHandler = async (storage: main.Storage) => {
  storageList.value = storageList.value.filter((item) => item.path !== storage.path)
  await SaveStorageList(storageList.value)
}
</script>
<template>
  <h1>SETTINGS STORAGE</h1>

  <Accordion value="0">
    <Button @click="createStorageHandler">Add storage</Button>
    <AccordionPanel v-for="(tab, index) in storageList" :key="tab.title" :value="tab.path">
      <AccordionHeader>
        <div class="flex w-full items-center justify-between gap-4">
          <div class="flex flex-col">
            <h3 class="text-lg">{{ `Storage_${index + 1}` }}</h3>
            <p class="text-xs">{{ tab.path }}</p>
          </div>
          <Button
            icon="pi pi-trash"
            severity="danger"
            text
            @click.stop="deleteStorageHandler(tab)"
          />
        </div>
      </AccordionHeader>
      <AccordionContent>
        <h3 class="m-0">Installed games</h3>
        <!-- <div v-for="app in tab.apps" :key="app">- {{ app }}</div> -->
      </AccordionContent>
    </AccordionPanel>
  </Accordion>
</template>
<style scoped></style>
