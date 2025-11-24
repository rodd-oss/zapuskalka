<script setup lang="ts">
import { usePocketBase } from '@/lib/usePocketbase'
import { AppsResponse, RecordIdString, type AppBuildsResponse } from 'backend-api'
import { ref } from 'vue'
import * as path from '@tauri-apps/api/path'
import { download } from '@tauri-apps/plugin-upload'
import { open } from '@tauri-apps/plugin-dialog'
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
  const storageFolder = await open({
    title: 'Where to create app folder?',
    canCreateDirectories: true,
    multiple: false,
    directory: true,
  })

  if (!storageFolder) {
    return
  }

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
    const message = err instanceof Error ? err.message : 'Unknown error occurred'
    actionError.value = message
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
    const message = err instanceof Error ? err.message : 'Unknown error occurred'
    actionError.value = message
    console.error('Update error:', err)
  } finally {
    activeAction.value = null
  }
}

const launch = async () => {
  if (config.value == undefined) {
    throw new Error('State error. Should not call if config is not loaded')
  }

  const entrypointPath = await path.join(config.value.installDir, build.id, build.entrypoint)

  await openPath(entrypointPath)
}

const close = async () => {}
</script>
<template>
  <div v-if="state == undefined">State loading...</div>
  <div v-else-if="state == 'error'" class="flex">
    <div>Error loading game state:</div>
    <div>
      {{ stateError }}
    </div>
  </div>
  <div v-else>
    <div v-if="state == 'not_installed'">
      <button
        class="cursor-pointer rounded bg-emerald-500 p-2 text-amber-50 hover:bg-emerald-400 disabled:cursor-not-allowed disabled:opacity-50"
        @click="install"
        :disabled="activeAction !== null"
      >
        Install
      </button>
    </div>
    <div v-else-if="state == 'need_update'">
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
  </div>
</template>
