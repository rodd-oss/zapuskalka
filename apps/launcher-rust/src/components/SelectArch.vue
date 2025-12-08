<script setup lang="ts">
import { AppBuildsArchOptions } from 'backend-api'

import { Select, createListCollection } from '@ark-ui/vue/select'
import { ChevronDownIcon } from 'lucide-vue-next'
import { computed } from 'vue'

const items: AppBuildsArchOptions[] = Object.values(AppBuildsArchOptions)
const collection = createListCollection({ items })

const selected = defineModel<keyof typeof AppBuildsArchOptions>()

const value = computed({
  get: () => (selected.value ? [selected.value] : []),
  set: (val: string[]) => (selected.value = val[0] as keyof typeof AppBuildsArchOptions),
})
</script>

<template>
  <div class="w-full max-w-sm">
    <Select.Root :collection="collection" v-model="value">
      <Select.Label class="mb-2 text-sm font-medium text-gray-900 dark:text-gray-100">
        Architecture
      </Select.Label>
      <Select.Control>
        <Select.Trigger
          class="flex h-10 w-full items-center justify-between rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 placeholder-gray-500 focus:border-gray-900 focus:ring-1 focus:ring-gray-900 focus:outline-none dark:border-gray-600 dark:bg-gray-800 dark:text-gray-100 dark:placeholder-gray-400 dark:focus:border-gray-100 dark:focus:ring-gray-100"
        >
          <Select.ValueText placeholder="Select target architecture" />
          <Select.Indicator>
            <ChevronDownIcon class="h-4 w-4 text-gray-500 dark:text-gray-400" />
          </Select.Indicator>
        </Select.Trigger>
      </Select.Control>
      <Teleport to="body">
        <Select.Positioner>
          <Select.Content
            class="z-50 min-w-(--reference-width) rounded-lg border border-gray-200 bg-white shadow-lg dark:border-gray-700 dark:bg-gray-800"
          >
            <Select.ItemGroup>
              <Select.ItemGroupLabel
                class="px-3 py-2 text-xs font-medium tracking-wide text-gray-500 uppercase dark:text-gray-400"
              >
                Select target architecture
              </Select.ItemGroupLabel>
              <Select.Item
                v-for="item in items"
                :key="item"
                :item="item"
                class="relative flex cursor-pointer items-center px-3 py-2 text-sm text-gray-900 select-none data-highlighted:bg-gray-100 data-[state=checked]:bg-gray-50 dark:text-gray-100 dark:data-highlighted:bg-gray-700 dark:data-[state=checked]:bg-gray-700"
              >
                <Select.ItemText>{{ item }}</Select.ItemText>
                <Select.ItemIndicator class="absolute right-3 text-blue-600 dark:text-blue-400">
                  ✓
                </Select.ItemIndicator>
              </Select.Item>
            </Select.ItemGroup>
          </Select.Content>
        </Select.Positioner>
      </Teleport>
      <Select.HiddenSelect />
    </Select.Root>
  </div>
</template>
