<script setup lang="ts">
import {
  type AppReleasesResponse,
  type AppsResponse,
  type AppBuildsResponse,
  type AppBuildsArchOptions,
  PublishersResponse,
} from 'backend-api'
import { useAuth, useAuthenticated, usePocketBase } from '@/lib/usePocketbase'
import { ref, watch } from 'vue'
import { useRoute } from 'vue-router'

import { type as os, arch } from '@tauri-apps/plugin-os'

import { Select, createListCollection } from '@ark-ui/vue/select'
import { ChevronDownIcon } from 'lucide-vue-next'
import { computed } from 'vue'
import LibraryAppController from '@/components/LibraryAppController.vue'
import DeveloperConsole from '@/components/DeveloperConsole.vue'

useAuthenticated()
const pb = usePocketBase()
const auth = useAuth()
const route = useRoute()

const app = ref<AppsResponse>()
const publisher = ref<PublishersResponse>()
const releases = ref<AppReleasesResponse[]>([])
const releasesMap = computed(() => {
  const m = new Map<string, AppReleasesResponse>()
  releases.value.forEach((r) => {
    m.set(r.id, r)
  })
  return m
})

const collection = computed(() =>
  createListCollection({
    items: releases.value,
    itemToString: (i) => i.name,
    itemToValue: (i) => i.id,
  }),
)
const selectedReleases = ref<string[]>([])
const selectedRelease = computed(() => selectedReleases.value.at(0))
const build = ref<AppBuildsResponse>()

watch(selectedRelease, async (newValue) => {
  const release = newValue
  if (release == undefined) {
    build.value = undefined
    console.log('release undefined')
    return
  }

  const builds = releasesMap.value.get(release)?.builds
  if (builds == undefined) {
    build.value = undefined
    console.log('builds undefined')
    return
  }

  if (builds.length == 0) {
    build.value = undefined
    console.log('no builds')
    return
  }

  const archs: (keyof typeof AppBuildsArchOptions)[] = [arch()]
  if (os() == 'macos') {
    archs.push('universal')
  }

  // Get all builds with any build id from the release that matches users os and arch
  const filterIds = builds.map((b) => `id='${b}'`).join('||')
  const filterArchs = archs.map((a) => `arch='${a}'`).join('||')
  const filter = `((${filterIds}) && (os='${os()}') && (${filterArchs}))`

  try {
    const fetchedBuild = await pb.collection('app_builds').getFirstListItem(filter)
    build.value = fetchedBuild
  } catch (err) {
    console.error(err)
  }
})

const fetchAppInfo = async (id: string | string[] | undefined) => {
  if (typeof id != 'string') {
    return
  }

  app.value = undefined
  publisher.value = undefined
  releases.value = []
  selectedReleases.value = []

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

    releases.value = await pb.collection('app_releases').getFullList({
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
</script>
<template>
  <div v-if="app && publisher" class="flex h-full w-full flex-col gap-4 p-4">
    <h1 class="text-6xl">{{ app.title }}</h1>
    <h3 class="text-xl">from {{ publisher.title }}</h3>

    <DeveloperConsole v-if="publisher.users.includes(auth.record.value!.id)" />

    <div class="w-full max-w-sm">
      <Select.Root :collection="collection" v-model="selectedReleases">
        <Select.Label class="mb-2 text-sm font-medium text-gray-900 dark:text-gray-100">
          Release
        </Select.Label>
        <Select.Control>
          <Select.Trigger
            class="flex h-10 w-full items-center justify-between rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 placeholder-gray-500 focus:border-gray-900 focus:ring-1 focus:ring-gray-900 focus:outline-none dark:border-gray-600 dark:bg-gray-800 dark:text-gray-100 dark:placeholder-gray-400 dark:focus:border-gray-100 dark:focus:ring-gray-100"
          >
            <Select.ValueText placeholder="Select release" />
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

    <div v-if="build">
      <LibraryAppController :build="build" :app="app" />
    </div>
    <div v-else-if="selectedRelease">No build available for your machine</div>
  </div>
</template>
<style scoped></style>
