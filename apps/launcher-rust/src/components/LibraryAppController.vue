<script setup lang="ts">
import { Popover } from '@ark-ui/vue/popover'
import { Dialog } from '@ark-ui/vue/dialog'
import { X, Trash } from 'lucide-vue-next'
import { usePocketBase } from '@/lib/usePocketbase'
import { type AppsResponse, type RecordIdString, type AppBuildsResponse } from 'backend-api'
import { ref } from 'vue'
import * as path from '@tauri-apps/api/path'
import * as z from 'zod'
import { download } from '@tauri-apps/plugin-upload'
import {
  exists,
  BaseDirectory,
  readTextFile,
  writeTextFile,
  mkdir,
  remove,
} from '@tauri-apps/plugin-fs'
import { openPath } from '@tauri-apps/plugin-opener'
import { onMounted } from 'vue'
import { Channel, invoke } from '@tauri-apps/api/core'
import { EllipsisVertical } from 'lucide-vue-next'

const METER_UPDATE_INTERVAL = 750

const safeJsonParse = <T,>(str: string) => {
  try {
    const jsonValue: T = JSON.parse(str)

    return jsonValue
  } catch {
    return undefined
  }
}

const ZAppConfig = z.object({
  id: z.custom<RecordIdString>((val) => typeof val === 'string'),
  buildId: z.custom<RecordIdString>((val) => typeof val === 'string'),
  installDir: z.string().min(1),
  storageDir: z.string().default(''),
  entrypoint: z.string().default(''),
})

type AppConfig = z.infer<typeof ZAppConfig>

interface ProgressEventData {
  current_bytes: number
  total_bytes: number
  delta_per_second: number
}

const { build, app } = defineProps<{ build: AppBuildsResponse; app: AppsResponse }>()

const pb = usePocketBase()

const files = build.files.map((filename) => {
  return {
    URL: pb.files.getURL(build, filename),
    name: filename,
  }
})
console.log(files)

const state = ref<'not_installed' | 'need_update' | 'ready' | 'error' | 'running'>()
const stateError = ref('')
const config = ref<AppConfig>()

type ActionType = 'install' | 'update' | 'download' | null
const activeAction = ref<ActionType>(null)
const actionProgress = ref(0)
const actionError = ref<string | null>(null)
const actionSuccess = ref(false)
const lastAction = ref<ActionType>(null)

const calculateState = async () => {
  state.value = undefined
  let file: string
  try {
    file = await readTextFile(`apps/${app.id}.json`, {
      baseDir: BaseDirectory.AppConfig,
    })
  } catch {
    state.value = 'not_installed'
    config.value = undefined
    return
  }
  const fileContent = safeJsonParse<AppConfig>(file)
  if (fileContent == undefined) {
    state.value = 'not_installed'
    // Bad config need to delete
    await removeAppConfig()
    return
  }

  const { error, data } = ZAppConfig.safeParse(safeJsonParse<AppConfig>(file))
  if (error !== undefined) {
    state.value = 'not_installed'
    // Bad config need to delete
    await removeAppConfig()
    return
  }

  config.value = data

  const installDirExists = await exists(config.value.installDir)
  if (!installDirExists) {
    state.value = 'not_installed'
    // Bad config need to delete
    await removeAppConfig()
    return
  }
  if (config.value.buildId != build.id) {
    state.value = 'need_update'
    return
  }

  if (config.value.storageDir == '') {
    const appDir = await path.appDataDir()
    config.value.storageDir = await path.join(appDir, 'storage')
    state.value = 'need_update'
    return
  }

  // Config need update
  if (config.value.entrypoint != build.entrypoint) {
    config.value.entrypoint = build.entrypoint
  }

  saveAppConfig(config.value)
  state.value = 'ready'
}

onMounted(calculateState)

// ask install dir
// create config file
const saveAppConfig = async (configData: AppConfig) => {
  const configDir = await path.appConfigDir()
  const appsConfigsDir = await path.join(configDir, 'apps')
  await mkdir(appsConfigsDir, {
    recursive: true,
  })

  const jsonConfig = JSON.stringify(configData)
  await writeTextFile(await path.join(appsConfigsDir, `${app.id}.json`), jsonConfig)
  config.value = configData
}

const removeAppConfig = async () => {
  console.log(`Removing ${app.title} config`)
  const configDir = await path.appConfigDir()
  const appsConfigsDir = await path.join(configDir, 'apps')

  const configPath = await path.join(appsConfigsDir, `${app.id}.json`)
  await remove(configPath, {
    recursive: true,
  })
}

const downloadAndExtractBuild = async (
  downloadRootDir: string,
  installDir: string,
  onProgress?: (value: number) => void,
) => {
  await mkdir(installDir, {
    recursive: true,
  })

  const downloadDirPath = await path.join(downloadRootDir, `temp_downloads_${build.id}`)
  await mkdir(downloadDirPath, {
    recursive: true,
  })
  activeAction.value = 'download'
  lastAction.value = 'download'
  const downloads = files.map(async (file) => {
    return path.join(downloadDirPath, file.name).then((saveFilePath) =>
      download(
        file.URL,
        saveFilePath,
        ({ total, progressTotal }) => {
          const perc = progressTotal / total
          onProgress?.(perc * 50)
          // console.log(`Downloaded ${progress} of ${total} with ${progressTotal} bytes ${perc}`)
        }, // a callback that will be called with the download progress // optional headers to send with the request
      ),
    )
  })
  await Promise.all(downloads)

  activeAction.value = 'install'
  lastAction.value = 'install'
  const extractions = files.map(async (file) => {
    const archivePath = await path.join(downloadDirPath, file.name)
    return invoke('extract_archive', {
      archivePath,
      destinationPath: installDir,
      progressChannel: new Channel<ProgressEventData>((progress) => {
        const pct = progress.current_bytes / progress.total_bytes
        onProgress?.(50 + pct * 45)
      }),
      speed_update_interval: METER_UPDATE_INTERVAL,
    })
  })
  await Promise.all(extractions)
  onProgress?.(95)

  await remove(downloadDirPath, {
    recursive: true,
  })
  onProgress?.(100)
}

const resetActionState = () => {
  actionError.value = null
  actionSuccess.value = false
  actionProgress.value = 0
}

const install = async () => {
  const appDir = await path.appDataDir()
  const storageDir = await path.join(appDir, 'storage')

  const installDir = await path.join(storageDir, app.title)
  activeAction.value = 'install'
  lastAction.value = 'install'
  resetActionState()
  try {
    // Remove previous installation contents to ensure clean state
    const installDirExists = await exists(installDir)
    if (installDirExists) {
      await remove(installDir, {
        recursive: true,
      })
    }

    await downloadAndExtractBuild(storageDir, installDir, (value) => {
      actionProgress.value = value
    })
    await saveAppConfig({
      id: app.id,
      installDir,
      storageDir,
      buildId: build.id,
      entrypoint: build.entrypoint,
    })
    actionSuccess.value = true
    actionProgress.value = 100
    await calculateState()
  } catch (err) {
    if (err instanceof Error) {
      actionError.value = err.message
    } else if (err instanceof String) {
      actionError.value = err.toString()
    } else if (typeof err == 'string') {
      actionError.value = err
    } else {
      actionError.value = 'Unknown error occurred'
    }
    console.error('Install error:', err)
  } finally {
    activeAction.value = null
  }
}

const update = async () => {
  if (!config.value?.installDir) {
    actionError.value = 'Cannot update because install directory is unknown'
    return
  }

  activeAction.value = 'update'
  lastAction.value = 'update'
  resetActionState()
  try {
    // Remove previous installation contents to ensure clean state
    const installDirExists = await exists(config.value.installDir)
    if (installDirExists) {
      await remove(config.value.installDir, {
        recursive: true,
      })
    }

    await downloadAndExtractBuild(config.value.storageDir, config.value.installDir, (value) => {
      actionProgress.value = value
    })
    const newConfig = config.value
    newConfig.buildId = build.id
    newConfig.entrypoint = build.entrypoint

    await saveAppConfig(newConfig)
    actionSuccess.value = true
    actionProgress.value = 100
    await calculateState()
  } catch (err) {
    if (err instanceof Error) {
      actionError.value = err.message
    } else if (err instanceof String) {
      actionError.value = err.toString()
    } else if (typeof err == 'string') {
      actionError.value = err
    } else {
      actionError.value = 'Unknown error occurred'
    }
    console.error('Update error:', err)
  } finally {
    activeAction.value = null
  }
}

const launch = async () => {
  await calculateState()

  if (state.value == 'need_update') {
    await update()
  }

  if (config.value == undefined) {
    throw new Error('State error. Should not call if config is not loaded')
  }

  try {
    await invoke('launch_app', { appId: config.value.id })
  } catch (e) {
    actionError.value = `failed launch application (${e})`
  }
}

const close = async () => {}

const openLocalFiles = async () => {
  if (config.value == undefined) {
    throw new Error('State error. Should not call if config is not loaded')
  }

  const entrypointPath = await path.join(config.value.installDir)

  await openPath(entrypointPath)
}

const deleteApp = async () => {
  if (config.value == undefined) {
    throw new Error('State error. Should not call if config is not loaded')
  }

  const installDirExists = await exists(config.value.installDir)
  if (installDirExists) {
    await remove(config.value.installDir, {
      recursive: true,
    })
  }

  await removeAppConfig()

  await calculateState()
}
</script>
<template>
  <div v-if="state == undefined">State loading...</div>
  <div v-else-if="state == 'error'" class="flex">
    <div>Error loading game state:</div>
    <div>
      {{ stateError }}
    </div>
  </div>
  <div v-else-if="state == 'not_installed'" class="flex flex-col">
    <button
      class="cursor-pointer rounded bg-emerald-500 p-2 text-amber-50 hover:bg-emerald-400 disabled:cursor-not-allowed disabled:opacity-50"
      @click="install"
      :disabled="activeAction !== null"
    >
      Install
    </button>
  </div>

  <div v-else class="flex">
    <div class="flex flex-row overflow-hidden rounded bg-emerald-600">
      <button
        v-if="state == 'need_update'"
        class="cursor-pointer bg-emerald-500 p-2 text-amber-50 hover:bg-emerald-400 disabled:cursor-not-allowed disabled:opacity-50"
        @click="update"
        :disabled="activeAction !== null"
      >
        Update
      </button>
      <button
        v-else-if="state == 'ready'"
        class="w-full cursor-pointer bg-emerald-500 p-2 text-amber-50 hover:bg-emerald-400 disabled:cursor-not-allowed disabled:opacity-50"
        @click="launch"
        :disabled="activeAction !== null"
      >
        Zapusk
      </button>
      <button
        v-else-if="state == 'running'"
        class="cursor-pointer bg-emerald-500 p-2 text-amber-50 hover:bg-emerald-400 disabled:cursor-not-allowed disabled:opacity-50"
        @click="close"
        :disabled="activeAction !== null"
      >
        Close
      </button>
      <Popover.Root>
        <Popover.Trigger
          class="inline-flex cursor-pointer items-center justify-center p-2 text-amber-50 hover:bg-emerald-400 disabled:cursor-not-allowed disabled:opacity-50"
          :disabled="activeAction !== null"
        >
          <EllipsisVertical :size="16" />
        </Popover.Trigger>
        <Teleport to="body">
          <Popover.Positioner>
            <Popover.Content
              class="data-[state=open]:animate-fade-in data-[state=closed]:animate-fade-out z-50 rounded-lg border border-gray-200 bg-white p-3 shadow-lg dark:border-gray-700 dark:bg-gray-800"
            >
              <Popover.Arrow
                class="[--arrow-background:var(--color-white)] [--arrow-size:12px] dark:[--arrow-background:var(--color-gray-800)]"
              >
                <Popover.ArrowTip class="border-t border-l border-gray-200 dark:border-gray-700" />
              </Popover.Arrow>

              <div class="flex flex-col gap-2">
                <Popover.CloseTrigger asChild>
                  <button
                    class="cursor-pointer rounded p-2 text-gray-900 hover:outline disabled:cursor-not-allowed disabled:opacity-50 dark:text-amber-50"
                    @click="openLocalFiles"
                    :disabled="activeAction !== null"
                  >
                    Browse local files
                  </button>
                </Popover.CloseTrigger>

                <Dialog.Root>
                  <Popover.CloseTrigger asChild>
                    <Dialog.Trigger asChild>
                      <button
                        class="inline-flex cursor-pointer items-center justify-center rounded bg-white px-4 py-2 text-red-500 transition-colors hover:outline dark:bg-gray-800"
                      >
                        Uninstall
                      </button>
                    </Dialog.Trigger>
                  </Popover.CloseTrigger>
                  <Teleport to="body">
                    <Dialog.Backdrop class="fixed inset-0 z-50 bg-black/50 backdrop-blur-xs" />
                    <Dialog.Positioner
                      class="fixed inset-0 z-50 flex items-center justify-center p-4"
                    >
                      <Dialog.Content
                        class="relative w-full max-w-sm rounded-lg bg-white p-5 shadow-lg dark:bg-gray-900"
                      >
                        <Dialog.CloseTrigger asChild>
                          <button
                            class="absolute top-3 right-3 cursor-pointer p-1 text-gray-400 transition-colors hover:text-gray-600 dark:hover:text-gray-300"
                          >
                            <X class="h-4 w-4" />
                          </button>
                        </Dialog.CloseTrigger>

                        <div class="space-y-4">
                          <div class="flex items-start space-x-3">
                            <div
                              class="flex h-10 w-10 items-center justify-center rounded-full border border-gray-300 bg-gray-50 dark:border-gray-600 dark:bg-gray-800"
                            >
                              <Trash class="h-5 w-5 text-gray-600 dark:text-white" />
                            </div>
                            <div class="space-y-1">
                              <Dialog.Title
                                class="text-lg font-semibold text-gray-900 dark:text-white"
                              >
                                Uninstall
                              </Dialog.Title>
                              <Dialog.Description class="text-sm text-gray-600 dark:text-gray-400">
                                Would you like to uninstall
                                <span class="font-bold text-emerald-400">{{ app.title }}</span> from
                                this device?
                              </Dialog.Description>
                            </div>
                          </div>

                          <div class="flex justify-end space-x-3">
                            <Dialog.CloseTrigger asChild>
                              <button
                                class="inline-flex cursor-pointer items-center justify-center rounded-md border border-gray-300 bg-white px-4 py-2 text-sm text-gray-900 transition-colors hover:bg-gray-50 dark:border-gray-600 dark:bg-gray-800 dark:text-white dark:hover:bg-gray-700"
                              >
                                Cancel
                              </button>
                            </Dialog.CloseTrigger>

                            <Dialog.CloseTrigger asChild>
                              <button
                                class="inline-flex cursor-pointer items-center justify-center rounded-md bg-red-500 px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-red-600"
                                @click="deleteApp"
                              >
                                Uninstall
                              </button>
                            </Dialog.CloseTrigger>
                          </div>
                        </div>
                      </Dialog.Content>
                    </Dialog.Positioner>
                  </Teleport>
                </Dialog.Root>
              </div>
            </Popover.Content>
          </Popover.Positioner>
        </Teleport>
      </Popover.Root>
    </div>
  </div>
  <div v-if="activeAction" class="mt-4 w-full">
    <div class="mb-2 text-sm text-gray-600 dark:text-gray-300">
      <span v-if="activeAction == 'install'">Installation in progress...</span>
      <span v-else-if="activeAction == 'update'">Update in progress...</span>
      <span v-else-if="activeAction == 'download'">Download in progress...</span>
    </div>
    <div class="h-2 w-full overflow-hidden rounded-full bg-gray-200 dark:bg-gray-700">
      <div
        class="h-full bg-emerald-500 transition-[width] duration-200 ease-out"
        :style="{ width: `${actionProgress}%` }"
      ></div>
    </div>
  </div>
  <div
    v-if="actionError"
    class="mt-4 w-full max-w-md rounded bg-red-100 px-4 py-2 text-sm text-red-800 dark:bg-red-900 dark:text-red-200"
  >
    Error: {{ actionError }}
  </div>
</template>
