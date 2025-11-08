<script setup lang="ts">
import BaseLayout from '@/layouts/BaseLayout.vue'
import { useAuthenticated } from '@/lib/usePocketbase'
import { ResizableHandle, ResizablePanel, ResizablePanelGroup } from '@/components/ui/resizable'

import { ScrollArea } from '@/components/ui/scroll-area'

const games: string[] = [
  'Counter-Strike 2',
  'Dota 2',
  'PUBG: BATTLEGROUNDS',
  'Apex Legends',
  "Baldur's Gate 3",
  'Grand Theft Auto V',
  'The Witcher 3: Wild Hunt',
  'Elden Ring',
  'Cyberpunk 2077',
  'Red Dead Redemption 2',
  'Half-Life: Alyx',
  'Portal 2',
  'Terraria',
  'Stardew Valley',
  'Hollow Knight',
  'Among Us',
  'Fall Guys',
  'Rocket League',
  'Team Fortress 2',
  'Left 4 Dead 2',
]

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
              :key="game"
              :to="'/library/' + game"
              class="max-w-[99%] px-4 py-0.5 font-medium text-gray-700 transition-colors hover:text-gray-900"
              active-class="text-gray-900 bg-blue-300"
            >
              {{ game }}
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
