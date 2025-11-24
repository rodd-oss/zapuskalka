<script setup lang="ts">
import Button from '@/components/ui/button/Button.vue'
import { type GamesResponse } from '@/lib/pocketbase-types'
import { useAuthenticated, usePocketBase } from '@/lib/usePocketbase'
import { RunGame } from '@/wailsjs/go/main/App'
import { EventsOn } from '@/wailsjs/runtime/runtime'
import { ref, watch } from 'vue'
import { useRoute } from 'vue-router'

useAuthenticated()
const pb = usePocketBase()
const route = useRoute()

const game = ref<GamesResponse>()

const fetchGameInfo = async (id: string | string[] | undefined) => {
  if (typeof id != 'string') {
    return
  }

  try {
    game.value = await pb.collection('games').getOne(id)
  } catch (error) {
    console.error(error)
  }
}

EventsOn('GameClosed', () => {})

watch(
  () => route.params.id,
  (id) => fetchGameInfo(id),
  {
    immediate: true,
  },
)

const zapusk = async () => {
  if (game.value == undefined) return
  await RunGame(game.value.id)
}
</script>
<template>
  <div class="flex flex-col gap-4 p-4">
    <h1 class="text-6xl">{{ game?.title }}</h1>
    <Button size="lg" :onclick="zapusk">ZAPUSK</Button>
  </div>
</template>
<style scoped></style>
