<script setup lang="ts">
import BaseLayout from '@/layouts/BaseLayout.vue'
import { useAuthenticated, usePocketBase } from '@/lib/usePocketbase'
import { ResizableHandle, ResizablePanel, ResizablePanelGroup } from '@/components/ui/resizable'

import { ScrollArea } from '@/components/ui/scroll-area'
import { onMounted, ref } from 'vue'
import type { GamesResponse } from '@/lib/pocketbase-types'
import { Search } from 'lucide-vue-next'
import Input from '@/components/ui/input/Input.vue'
import { computed } from 'vue'

const games = ref<GamesResponse[]>([])

const pb = usePocketBase()

onMounted(async () => {
  try {
    const res = await pb.collection('games').getFullList()
    games.value = res
  } catch (error) {
    console.error(error)
  }
})

const searchFilter = ref('')
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
    <ResizablePanelGroup direction="horizontal">
      <ResizablePanel class="max-w-1/2 min-w-60" :default-size="25">
        <div class="relative w-full items-center p-2">
          <Input
            id="search"
            v-model="searchFilter"
            type="text"
            placeholder="Search..."
            class="w-full pl-10"
          />
          <span class="absolute inset-y-0 start-0 flex items-center justify-center px-4">
            <Search class="text-muted-foreground size-6" />
          </span>
        </div>
        <ScrollArea class="h-full">
          <div class="flex flex-col">
            <RouterLink
              v-for="game in filteredGames"
              :key="game.id"
              :to="'/library/' + game.id"
              class="max-w-[99%] px-4 py-0.5 font-medium text-gray-700 transition-colors hover:text-gray-900"
              active-class="text-gray-900 bg-blue-300"
            >
              {{ game.title }}
            </RouterLink>
          </div>
        </ScrollArea>
      </ResizablePanel>
      <ResizableHandle />
      <ResizablePanel :default-size="75"><RouterView /></ResizablePanel>
    </ResizablePanelGroup>
  </BaseLayout>
</template>
<style scoped></style>
