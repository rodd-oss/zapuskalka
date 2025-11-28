<script setup lang="ts">
import { Popover } from '@ark-ui/vue/popover'
import { Dialog } from '@ark-ui/vue/dialog'
import { X, Trash } from 'lucide-vue-next'
import { usePocketBase } from '@/lib/usePocketbase'
import { AppsResponse, RecordIdString, type AppBuildsResponse } from 'backend-api'
import { ref } from 'vue'
import * as path from '@tauri-apps/api/path'
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
import { invoke } from '@tauri-apps/api/core'
import { ChevronDown } from 'lucide-vue-next'

const safeJsonParse = <T,>(str: string) => {
  try {
    const jsonValue: T = JSON.parse(str)

    return jsonValue
  } catch {
    return undefined
  }
}

interface AppConfig {
  id: RecordIdString
  installDir: string
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

type ActionType = 'install' | 'update' | null
const activeAction = ref<ActionType>(null)
const actionProgress = ref(0)
const actionError = ref<string | null>(null)
const actionSuccess = ref(false)
const lastAction = ref<ActionType>(null)

const calculateState = async () => {
  try {
    state.value = undefined
    try {
      const file = await readTextFile(`apps/${app.id}.json`, {
        baseDir: BaseDirectory.AppConfig,
      })
      config.value = safeJsonParse(file)
    } catch {
      state.value = 'not_installed'
      return
    }
    if (config.value == undefined) {
      state.value = 'not_installed'
      // TODO: bad config need to delete
      return
    }
    if (config.value.installDir == '') {
      state.value = 'not_installed'
      console.error('bad config need to delete')
      // TODO: bad config need to delete
      return
    }
    const installDirExists = await exists(config.value.installDir)
    if (!installDirExists) {
      state.value = 'not_installed'
      console.error('bad config need to delete')
      // TODO: bad config need to delete
      return
    }
    const buildDirExists = await exists(await path.join(config.value.installDir, build.id))
    if (!buildDirExists) {
      state.value = 'need_update'
      return
    }
    state.value = 'ready'
  } catch (err) {
    console.error(err)
    stateError.value = err as string
    state.value = 'error'
    return
  }
}

onMounted(calculateState)

// ask install dir
// create config file
const saveAppConfig = async (installDir: string) => {
  const configDir = await path.appConfigDir()
  const appsConfigsDir = await path.join(configDir, 'apps')
  await mkdir(appsConfigsDir, {
    recursive: true,
  })

  const configData: AppConfig = {
    id: app.id,
    installDir,
  }
  const jsonConfig = JSON.stringify(configData)
  await writeTextFile(await path.join(appsConfigsDir, `${app.id}.json`), jsonConfig)
  config.value = configData
}

const removeAppConfig = async () => {
  const configDir = await path.appConfigDir()
  const appsConfigsDir = await path.join(configDir, 'apps')

  const configPath = await path.join(appsConfigsDir, `${app.id}.json`)
  await remove(configPath, {
    recursive: true,
  })
}

const downloadAndExtractBuild = async (
  installDir: string,
  onProgress?: (value: number) => void,
) => {
  // Remove previous installation contents to ensure clean state
  const installDirExists = await exists(installDir)
  if (installDirExists) {
    await remove(installDir, {
      recursive: true,
    })
  }

  await mkdir(installDir, {
    recursive: true,
  })
  onProgress?.(5)

  const downloadDirPath = await path.join(installDir, `temp_downloads_${build.id}`)
  await mkdir(downloadDirPath, {
    recursive: true,
  })
  const downloads = files.map(async (file) => {
    return path.join(downloadDirPath, file.name).then((saveFilePath) =>
      download(
        file.URL,
        saveFilePath,
        ({ progress, total }) => console.log(`Downloaded ${progress} of ${total} bytes`), // a callback that will be called with the download progress // optional headers to send with the request
      ),
    )
  })
  await Promise.all(downloads)
  onProgress?.(40)

  //remove build folder if exists
  const exctractDirPath = await path.join(installDir, build.id)
  const extractDirExists = await exists(exctractDirPath)
  if (extractDirExists) {
    await remove(exctractDirPath, {
      recursive: true,
    })
  }

  await mkdir(exctractDirPath, {
    recursive: true,
  })

  const extractions = files.map(async (file) => {
    const archivePath = await path.join(downloadDirPath, file.name)
    return invoke('extract_archive', {
      archivePath,
      destinationPath: exctractDirPath,
    })
  })
  await Promise.all(extractions)
  onProgress?.(90)

  await remove(downloadDirPath, {
    recursive: true,
  })
  onProgress?.(100)
}

const describeAction = (action: ActionType | null) => {
  if (action === 'install') return 'Installation'
  if (action === 'update') return 'Update'
  return ''
}

const resetActionState = () => {
  actionError.value = null
  actionSuccess.value = false
  actionProgress.value = 0
}

const install = async () => {
  const storageFolder = await path.appDataDir()

  const installDir = await path.join(storageFolder, app.title)
  activeAction.value = 'install'
  lastAction.value = 'install'
  resetActionState()
  try {
    await downloadAndExtractBuild(installDir, (value) => {
      actionProgress.value = value
    })
    await saveAppConfig(installDir)
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
    await downloadAndExtractBuild(config.value.installDir, (value) => {
      actionProgress.value = value
    })
    await saveAppConfig(config.value.installDir)
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

  const entrypointPath = await path.join(config.value.installDir, build.id, build.entrypoint)

  await openPath(entrypointPath)
}

const close = async () => {}

const openLocalFiles = async () => {
  if (config.value == undefined) {
    throw new Error('State error. Should not call if config is not loaded')
  }

  const entrypointPath = await path.join(config.value.installDir, build.id)

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
  <div v-else-if="state == 'not_installed'">
    <button
      class="cursor-pointer rounded bg-emerald-500 p-2 text-amber-50 hover:bg-emerald-400 disabled:cursor-not-allowed disabled:opacity-50"
      @click="install"
      :disabled="activeAction !== null"
    >
      Install
    </button>
  </div>

  <div v-else class="flex flex-row">
    <div v-if="state == 'need_update'">
      <button
        class="cursor-pointer rounded bg-emerald-500 p-2 text-amber-50 hover:bg-emerald-400 disabled:cursor-not-allowed disabled:opacity-50"
        @click="update"
        :disabled="activeAction !== null"
      >
        Update
      </button>
    </div>
    <div v-else-if="state == 'ready'">
      <button
        class="cursor-pointer rounded bg-emerald-500 p-2 text-amber-50 hover:bg-emerald-400 disabled:cursor-not-allowed disabled:opacity-50"
        @click="launch"
        :disabled="activeAction !== null"
      >
        Zapusk
      </button>
    </div>
    <div v-else-if="state == 'running'">
      <button
        class="cursor-pointer rounded bg-emerald-500 p-2 text-amber-50 hover:bg-emerald-400 disabled:cursor-not-allowed disabled:opacity-50"
        @click="close"
        :disabled="activeAction !== null"
      >
        Close
      </button>
    </div>
    <Popover.Root>
      <Popover.Trigger
        class="inline-flex items-center justify-center rounded-lg border border-gray-300 bg-white p-2 text-gray-700 hover:bg-gray-50 focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 focus:outline-none dark:border-gray-600 dark:bg-gray-800 dark:text-gray-200 dark:hover:bg-gray-700"
      >
        <ChevronDown :size="16" />
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
  <div v-if="activeAction" class="mt-4 w-full max-w-md">
    <div class="mb-2 text-sm text-gray-600 dark:text-gray-300">
      {{ describeAction(activeAction) }} in progress...
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
