<script setup lang="ts">
import BaseLayout from '@/layouts/BaseLayout.vue'
import { useAuthenticated, usePocketBase } from '@/lib/usePocketbase'
import { ResizableHandle, ResizablePanel, ResizablePanelGroup } from '@/components/ui/resizable'

import { ScrollArea } from '@/components/ui/scroll-area'
import { onMounted, ref } from 'vue'
import type { GamesResponse } from '@/lib/pocketbase-types'

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

useAuthenticated()
</script>
<template>
  <BaseLayout>
    <ResizablePanelGroup direction="horizontal">
      <ResizablePanel class="max-w-1/2 min-w-60" :default-size="25">
        <h4 class="p-4 text-sm leading-none font-medium">My games</h4>
        <ScrollArea class="h-full">
          <div class="flex flex-col">
            <RouterLink
              v-for="game in games"
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
