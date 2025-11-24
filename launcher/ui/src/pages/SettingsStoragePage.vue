<script setup lang="ts">
import Button from '@/components/ui/button/Button.vue'
import { useAuthenticated } from '@/lib/usePocketbase'
import { LoadStorageList, OsOpenFolder, SaveStorageList } from '@/wailsjs/go/main/App'
import type { main } from '@/wailsjs/go/models'
import { Accordion, AccordionItem, AccordionItemIndicator, AccordionItemTrigger } from '@ark-ui/vue'
import { ChevronDown } from 'lucide-vue-next'
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
  <Button @click="createStorageHandler">Add storage</Button>
  <Accordion.Root
    :default-value="['0']"
    collapsible
    class="mx-auto w-full max-w-md bg-linear-to-br from-gray-100/80 to-gray-200/80 backdrop-blur-xs dark:from-gray-900/80 dark:to-gray-800/80"
  >
    <AccordionItem
      v-for="(tab, index) in storageList"
      :key="tab.title"
      :value="tab.path"
      class="group border-b border-gray-200/50 last:border-b-0 dark:border-gray-700/50"
    >
      <AccordionItemTrigger
        class="flex w-full items-center justify-between px-4 py-3 text-left transition-all duration-200 hover:bg-linear-to-r hover:from-blue-500/5 hover:to-purple-500/5"
      >
        <span class="font-medium text-gray-900 dark:text-white">
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
        </span>
        <AccordionItemIndicator
          class="ml-2 transition-transform duration-200 data-[state=open]:rotate-180"
        >
          <ChevronDown class="h-4 w-4 text-gray-600 dark:text-gray-400" />
        </AccordionItemIndicator>
      </AccordionItemTrigger>
      <AccordionItemContent
        class="px-4 pb-3 text-sm leading-relaxed text-gray-700 dark:text-gray-300"
      >
        <h3 class="m-0">Installed games</h3>
      </AccordionItemContent>
    </AccordionItem>
  </Accordion.Root>
</template>
<style scoped></style>
