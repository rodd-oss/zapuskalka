<script setup lang="ts">
import AccountMenu from '@/components/AccountMenu.vue'
import { Tabs } from '@ark-ui/vue/tabs'
import { computed } from 'vue'
import { useRoute } from 'vue-router'

const route = useRoute()

const items = computed(() => [
  // {
  //   label: 'Home',
  //   to: '/',
  //   active: route.path == '/',
  // },
  {
    label: 'Library',
    to: '/library',
    active: route.path.startsWith('/library'),
  },
  // {
  //   label: 'Settings',
  //   to: '/settings',
  //   active: route.path.startsWith('/settings'),
  // },
])
</script>
<template>
  <div class="flex h-screen w-full flex-col bg-white px-4 py-4 dark:bg-gray-800">
    <div class="flex w-full items-center justify-between pb-2">
      <Tabs.Root :model-value="route.path" class="flex flex-col items-center">
        <Tabs.List class="relative flex w-fit border-b border-gray-200 dark:border-gray-700">
          <Tabs.Trigger
            v-for="tab in items"
            :key="tab.to"
            :value="tab.to"
            class="relative w-18 border-b-2 border-transparent py-2 text-center text-sm font-medium text-gray-500 transition-colors hover:text-gray-700 data-selected:border-gray-900 data-selected:text-gray-900 dark:text-gray-400 dark:hover:text-gray-200 dark:data-selected:border-gray-100 dark:data-selected:text-gray-100"
            as-child
          >
            <RouterLink :to="tab.to">{{ tab.label }}</RouterLink>
          </Tabs.Trigger>
          <Tabs.Indicator />
        </Tabs.List>
      </Tabs.Root>

      <AccountMenu />
    </div>

    <slot />
  </div>
</template>
