<script setup lang="ts">
import { Menu } from '@ark-ui/vue/menu'
import { ChevronDown } from 'lucide-vue-next'
import DeveloperUploadBuild from './DeveloperUploadBuild.vue'
import type { AppBranchesResponse, AppsResponse } from 'backend-api'

const { app, branch } = defineProps<{ app: AppsResponse; branch: AppBranchesResponse }>()
</script>

<template>
  <Menu.Root>
    <Menu.Trigger
      class="inline-flex items-center gap-2 rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 focus:ring-2 focus:ring-gray-900 focus:ring-offset-2 focus:outline-hidden dark:border-gray-700 dark:bg-gray-900 dark:text-gray-300 dark:hover:bg-gray-800 dark:focus:ring-gray-100"
    >
      Developer Menu
      <ChevronDown class="h-4 w-4" />
    </Menu.Trigger>
    <Teleport to="body">
      <Menu.Positioner>
        <Menu.Content
          class="z-50 min-w-48 rounded-lg border border-gray-200 bg-white p-1 shadow-lg focus-visible:outline-hidden dark:border-gray-700 dark:bg-gray-900"
        >
          <DeveloperUploadBuild :app="app" :branch="branch">
            <Menu.Item
              value="upload-build"
              class="flex cursor-pointer items-center gap-2 rounded-md px-3 py-2 text-sm text-gray-700 hover:bg-gray-100 focus:bg-gray-100 dark:text-gray-300 dark:hover:bg-gray-800 dark:focus:bg-gray-800"
            >
              Upload build
            </Menu.Item>
          </DeveloperUploadBuild>
        </Menu.Content>
      </Menu.Positioner>
    </Teleport>
  </Menu.Root>
</template>
