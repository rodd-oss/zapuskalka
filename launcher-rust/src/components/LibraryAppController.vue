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

// open config file {gameId}.json
// if not -> state = notIstalled
// get installDir path
// if installDir not exists -> state = notIstalled, remove config
// if installDir/{buildid} not exists -> state = needUpdate
//
// if state notInstalled show install button
// else if state needUpdate show update button
// else show launch button

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
      // TODO: bad config need to delete
      return
    }
    const installDirExists = await exists(config.value.installDir)
    if (!installDirExists) {
      state.value = 'not_installed'
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

const downloadAndExtractBuild = async (installDir: string) => {
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

  await remove(downloadDirPath, {
    recursive: true,
  })
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
  await downloadAndExtractBuild(installDir)
  await saveAppConfig(installDir)

  await calculateState()
}

const update = async () => {
  if (!config.value?.installDir) {
    throw new Error('Cannot update because install directory is unknown')
  }

  await downloadAndExtractBuild(config.value.installDir)
  await saveAppConfig(config.value.installDir)
  await calculateState()
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
        class="cursor-pointer rounded bg-emerald-500 p-2 text-amber-50 hover:bg-emerald-400"
        @click="install"
      >
        Install
      </button>
    </div>
    <div v-else-if="state == 'need_update'">
      <button
        class="cursor-pointer rounded bg-emerald-500 p-2 text-amber-50 hover:bg-emerald-400"
        @click="update"
      >
        Update
      </button>
    </div>
    <div v-else-if="state == 'ready'">
      <button
        class="cursor-pointer rounded bg-emerald-500 p-2 text-amber-50 hover:bg-emerald-400"
        @click="launch"
      >
        Zapusk
      </button>
    </div>
    <div v-else-if="state == 'running'">
      <button
        class="cursor-pointer rounded bg-emerald-500 p-2 text-amber-50 hover:bg-emerald-400"
        @click="close"
      >
        Close
      </button>
    </div>
  </div>
</template>
