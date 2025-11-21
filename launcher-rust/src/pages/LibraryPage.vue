<script setup lang="ts">
import { Splitter } from '@ark-ui/vue/splitter'
import BaseLayout from '@/layouts/BaseLayout.vue'
import { useAuthenticated, usePocketBase } from '@/lib/usePocketbase'

import { onMounted, ref } from 'vue'
import { computed } from 'vue'
import { ScrollArea } from '@ark-ui/vue'
import Input from '@/components/ui/Input.vue'
import { AppsResponse } from 'backend-api'

const games = ref<AppsResponse[]>([])

const pb = usePocketBase()

onMounted(async () => {
  try {
    const res = await pb.collection('apps').getFullList()
    games.value = res
  } catch (error) {
    console.error(error)
  }
})

const searchFilter = ref<string>('')
const filteredGames = computed(() => {
  if (searchFilter.value.trim() == '') return games.value

  return games.value.filter((game) => {
    // TODO: fuzzy search
    if (game.title.toLocaleLowerCase().includes(searchFilter.value.toLocaleLowerCase())) {
      return true
    }

    return false
  })
})

useAuthenticated()
</script>
<template>
  <BaseLayout>
    <div class="px py flex h-full w-full items-center justify-center bg-white dark:bg-gray-800">
      <div class="h-full w-full">
        <Splitter.Root
          :panels="[{ id: 'a', minSize: 30, maxSize: 50 }, { id: 'b' }]"
          :default-size="[30, 70]"
          class="flex h-full gap-1"
        >
          <Splitter.Panel
            id="a"
            class="flex flex-col items-start justify-start border border-gray-200 bg-gray-50 text-gray-600 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-400"
          >
            <label class="w-full bg-gray-800 p-2">
              <Input class="w-full" placeholder="Search" v-model="searchFilter" />
            </label>
            <ScrollArea.Root class="h-full w-full">
              <ScrollArea.Viewport class="h-full">
                <ScrollArea.Content class="flex h-full flex-col">
                  <RouterLink
                    v-for="game in filteredGames"
                    :key="game.id"
                    :to="`/library/${game.id}`"
                    class="p-2"
                    active-class="bg-gray-700 text-gray-50"
                  >
                    {{ game.title }}
                  </RouterLink>
                </ScrollArea.Content>
              </ScrollArea.Viewport>
              <ScrollArea.Scrollbar>
                <ScrollArea.Thumb />
              </ScrollArea.Scrollbar>
              <ScrollArea.Corner />
            </ScrollArea.Root>
          </Splitter.Panel>
          <Splitter.ResizeTrigger
            id="a:b"
            aria-label="Resize"
            class="min-w-1.5 bg-gray-300 transition-colors duration-200 outline-none hover:bg-gray-400 active:bg-gray-400 dark:bg-gray-600 dark:hover:bg-gray-500 dark:active:bg-gray-500"
          />
          <Splitter.Panel
            id="b"
            class="flex items-center justify-center border border-gray-200 bg-gray-50 text-gray-600 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-400"
          >
            <RouterView />
          </Splitter.Panel>
        </Splitter.Root>
      </div>
    </div>
  </BaseLayout>
</template>
<style scoped></style>
