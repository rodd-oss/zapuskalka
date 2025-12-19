<script setup lang="ts">
import {
  type AppBranchesResponse,
  type AppsResponse,
  type AppBuildsResponse,
  type AppBuildsArchOptions,
  type PublishersResponse,
} from 'backend-api'
import { useAuth, useAuthenticated, usePocketBase } from '@/lib/usePocketbase'
import { ref, watch } from 'vue'
import { useRoute } from 'vue-router'

import { type as os, arch } from '@tauri-apps/plugin-os'

import { Select, createListCollection } from '@ark-ui/vue/select'
import { ChevronDownIcon } from 'lucide-vue-next'
import { computed } from 'vue'
import LibraryAppController from '@/components/LibraryAppController.vue'
import DeveloperMenu from '@/components/DeveloperMenu.vue'

useAuthenticated()
const pb = usePocketBase()
const route = useRoute()
const auth = useAuth()

const app = ref<AppsResponse>()
const publisher = ref<PublishersResponse>()
const branches = ref<AppBranchesResponse[]>([])

const collection = computed(() =>
  createListCollection({
    items: branches.value,
    itemToString: (i) => i.name,
    itemToValue: (i) => i.id,
  }),
)
const selectedBranchesIds = ref<string[]>([])
const selectedBranchId = computed(() => selectedBranchesIds.value.at(0))
const selectedBranch = ref<AppBranchesResponse>()
const build = ref<AppBuildsResponse>()

watch(selectedBranchId, async (newBranchId) => {
  if (newBranchId == undefined) {
    build.value = undefined
    console.error('branch undefined')
    return
  }

  selectedBranch.value = await pb.collection('app_branches').getOne(newBranchId)
  if (selectedBranch.value == undefined) {
    console.error('branch not found')
    return
  }

  const archs: (AppBuildsArchOptions)[] = [arch()]
  if (os() == 'macos') {
    archs.push('universal')
  }

  // Get all builds with any build id from the release that matches users os and arch
  const filterArchs = archs.map((a) => `arch='${a}'`).join('||')
  const filter = `((branch='${newBranchId}') && (os='${os()}') && (${filterArchs}))`

  try {
    const fetchedBuild = await pb.collection('app_builds').getFirstListItem(filter, {
      sort: '-updated',
    })
    build.value = fetchedBuild
  } catch (err) {
    build.value = undefined
    console.error(err)
  }
})

const fetchAppInfo = async (id: string | string[] | undefined) => {
  if (typeof id != 'string') {
    return
  }

  app.value = undefined
  publisher.value = undefined
  branches.value = []
  selectedBranchesIds.value = []

  build.value = undefined

  try {
    app.value = await pb.collection('apps').getOne(id)
    if (app.value == undefined) {
      throw new Error('app undefined')
    }

    publisher.value = await pb.collection('publishers').getOne(app.value.publisher)
    if (publisher.value == undefined) {
      throw new Error('publisher undefined')
    }

    if (app.value.default_branch != undefined) {
      selectedBranchesIds.value = [app.value.default_branch]
    }

    branches.value = await pb.collection('app_branches').getFullList({
      filter: `app="${app.value.id}"`,
    })
  } catch (error) {
    console.error(error)
  }
}

watch(
  () => route.params.id,
  (id) => fetchAppInfo(id),
  {
    immediate: true,
  },
)

const isPublisher = computed(() => {
  if (publisher.value == undefined) {
    return false
  }

  if (auth.user.value == undefined) {
    return false
  }

  if (publisher.value.users == undefined) {
    return false
  }

  return publisher.value.users.includes(auth.user.value.id) ?? false
})
</script>
<template>
  <div v-if="app && publisher" class="flex h-full w-full flex-col gap-4 p-4">
    <h1 class="text-6xl">{{ app.title }}</h1>
    <h3 class="text-xl">from {{ publisher.title }}</h3>

    <div class="flex justify-between">
      <div class="w-full max-w-sm gap-2">
        <Select.Root :collection="collection" v-model="selectedBranchesIds">
          <Select.Label class="mb-2 text-sm font-medium text-gray-900 dark:text-gray-100">
            Branch
          </Select.Label>
          <Select.Control>
            <Select.Trigger
              class="flex h-10 w-full items-center justify-between rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 placeholder-gray-500 focus:border-gray-900 focus:ring-1 focus:ring-gray-900 focus:outline-none dark:border-gray-600 dark:bg-gray-800 dark:text-gray-100 dark:placeholder-gray-400 dark:focus:border-gray-100 dark:focus:ring-gray-100"
            >
              <Select.ValueText placeholder="Select branch" />
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
                  <Select.Item
                    v-for="item in collection.items"
                    :key="item.name"
                    :item="item.id"
                    class="relative flex cursor-pointer items-center px-3 py-2 text-sm text-gray-900 select-none data-highlighted:bg-gray-100 data-[state=checked]:bg-gray-50 dark:text-gray-100 dark:data-highlighted:bg-gray-700 dark:data-[state=checked]:bg-gray-700"
                  >
                    <Select.ItemText>{{ item.name }}</Select.ItemText>
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
      <template v-if="selectedBranch != undefined">
        <DeveloperMenu v-if="isPublisher" :app="app" :branch="selectedBranch" />
      </template>
    </div>

    <div v-if="build">
      <LibraryAppController :build="build" :app="app" />
    </div>
    <div v-else-if="selectedBranchId">No build available for your machine</div>
  </div>
</template>
<style scoped></style>
