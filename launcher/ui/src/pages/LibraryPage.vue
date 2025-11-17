<script setup lang="ts">
import BaseLayout from '@/layouts/BaseLayout.vue'
import { useAuthenticated, usePocketBase } from '@/lib/usePocketbase'

import { onMounted, ref } from 'vue'
import type { GamesResponse } from '@/lib/pocketbase-types'
import { computed } from 'vue'
import type { NavigationMenuItem } from '@nuxt/ui'

const items: NavigationMenuItem[][] = [
  [
    {
      label: 'Home',
      icon: 'i-lucide-house',
      active: true,
    },
    {
      label: 'Inbox',
      icon: 'i-lucide-inbox',
      badge: '4',
    },
    {
      label: 'Contacts',
      icon: 'i-lucide-users',
    },
    {
      label: 'Settings',
      icon: 'i-lucide-settings',
      defaultOpen: true,
      children: [
        {
          label: 'General',
        },
        {
          label: 'Members',
        },
        {
          label: 'Notifications',
        },
      ],
    },
  ],
  [
    {
      label: 'Feedback',
      icon: 'i-lucide-message-circle',
      to: 'https://github.com/nuxt-ui-templates/dashboard',
      target: '_blank',
    },
    {
      label: 'Help & Support',
      icon: 'i-lucide-info',
      to: 'https://github.com/nuxt/ui',
      target: '_blank',
    },
  ],
]

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
    <UDashboardGroup unit="%">
      <div class="flex flex-1">
        <UDashboardPanel id="inbox-1" resizable> jksdjfkd </UDashboardPanel>
      </div>
      <RouterView />
    </UDashboardGroup>
  </BaseLayout>
</template>
<style scoped></style>
