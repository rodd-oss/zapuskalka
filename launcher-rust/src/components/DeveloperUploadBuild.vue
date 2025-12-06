<script setup lang="ts">
import { Dialog } from '@ark-ui/vue/dialog'
import { X } from 'lucide-vue-next'
import { computed, onUnmounted, ref, watch } from 'vue'
import SelectOs from './SelectOs.vue'
import SelectArch from './SelectArch.vue'
import EntrypointField from './EntrypointField.vue'
import DirectoryUpload from './DirectoryUpload.vue'
import { usePocketBase } from '@/lib/usePocketbase'

const METER_UPDATE_INTERVAL = 750

import { Channel, invoke } from '@tauri-apps/api/core'
import {
  type AppBranchesResponse,
  AppBuildsArchOptions,
  AppBuildsInstallRulesOptions,
  AppBuildsOsOptions,
  type AppsResponse,
  Collections,
  type Create,
} from 'backend-api'
import { remove } from '@tauri-apps/plugin-fs'
import { DeltaMeter } from '@/lib/DeltaMeter'
import { humanReadableByteSize } from '@/lib/utils'

interface ProgressEventData {
  current_bytes: number
  total_bytes: number
}

enum Stage {
  FillingForm,
  Packing,
  Uploading,
  Done,
}

const props = defineProps<{ app: AppsResponse; branch: AppBranchesResponse }>()

const dirPath = ref<string>()
const os = ref<keyof typeof AppBuildsOsOptions>()
const arch = ref<keyof typeof AppBuildsArchOptions>()
const entrypoint = ref<string>('')

const pb = usePocketBase()
const currentStage = ref(Stage.FillingForm)
const stageProgress = ref(0)
const progressDetails = ref('')
const progressMeter = ref<DeltaMeter | null>(null)
const error = ref<string | null>(null)
const success = ref(false)

watch(progressMeter, (newValue, oldValue) => {
  oldValue?.stop()
  newValue?.reset()
})

onUnmounted(() => {
  // stop inner timer
  progressMeter.value = null
})

const formIsValid = computed<boolean>(() => {
  if (os.value == undefined || arch.value == undefined || dirPath.value == undefined) {
    return false
  }

  if (entrypoint.value.trim() == '') {
    return false
  }

  return true
})

const uploadBuildHandler = async () => {
  if (os.value == undefined || arch.value == undefined || dirPath.value == undefined) {
    return
  }

  if (entrypoint.value.trim() == '') {
    return false
  }

  let archivePath = ''

  try {
    error.value = null
    success.value = false
    currentStage.value = Stage.Packing
    stageProgress.value = 0

    // Step 1: Archive and compress the folder using Rust
    progressMeter.value = new DeltaMeter(METER_UPDATE_INTERVAL)
    archivePath = await invoke<string>('archive_and_compress_folder', {
      folderPath: dirPath.value,
      progressChannel: new Channel<ProgressEventData>((progress) => {
        progressMeter.value?.sample(progress.current_bytes)
        stageProgress.value = (progress.current_bytes / progress.total_bytes) * 100.0
        progressDetails.value = `${humanReadableByteSize(progressMeter.value?.avg ?? 0)}/s`
      }),
    })
    progressMeter.value = null

    const data: Create<Collections.AppBuilds> = {
      app: props.app.id,
      branch: props.branch.id,
      os: AppBuildsOsOptions[os.value],
      arch: AppBuildsArchOptions[arch.value],
      install_rules: [
        AppBuildsInstallRulesOptions.direct_copy,
        AppBuildsInstallRulesOptions.untar,
        AppBuildsInstallRulesOptions.ungzip,
      ],
      entrypoint: entrypoint.value,
    }

    console.log(data)

    currentStage.value = Stage.Uploading
    stageProgress.value = 0

    const buildRecord = await pb.collection('app_builds').create(data)
    console.log('build record' + buildRecord)

    const url = `${pb.baseURL}/api/collections/app_builds/records/${buildRecord.id}`

    // TODO: migrate to one-shot build creation from rust side
    // Use custom Rust function that properly creates multipart/form-data with "files" field
    // This ensures correct boundary and field name for PocketBase
    progressMeter.value = new DeltaMeter(METER_UPDATE_INTERVAL)
    await invoke('upload_file_as_form_data', {
      url,
      filePath: archivePath,
      authToken: pb.authStore.token || null,
      progressChannel: new Channel<ProgressEventData>((progress) => {
        progressMeter.value?.sample(progress.current_bytes)
        stageProgress.value = (progress.current_bytes / progress.total_bytes) * 100.0
        progressDetails.value = `${humanReadableByteSize(progressMeter.value?.avg ?? 0)}/s`
      }),
    })
    progressMeter.value = null
    progressDetails.value = ''

    success.value = true
    stageProgress.value = 100
  } catch (err) {
    if (err instanceof Error) {
      error.value = err.message
    } else if (err instanceof String) {
      error.value = err.toString()
    } else if (typeof err == 'string') {
      error.value = err
    } else {
      error.value = 'Unknown error occurred'
    }

    console.error('Upload error:', err)
  } finally {
    currentStage.value = Stage.Done
    if (archivePath != '') {
      await remove(archivePath, {
        recursive: true,
      })
    }
  }
}

const resetState = (open: boolean) => {
  if (open == true) {
    return
  }

  if (success.value) {
    dirPath.value = undefined
    os.value = undefined
    arch.value = undefined
    entrypoint.value = ''

    success.value = false
    currentStage.value = Stage.FillingForm
  }
}
</script>

<template>
  <Dialog.Root @update:open="resetState">
    <Dialog.Trigger asChild>
      <slot />
    </Dialog.Trigger>
    <Teleport to="body">
      <Dialog.Backdrop class="fixed inset-0 z-50 bg-black/50 backdrop-blur-xs" />
      <Dialog.Positioner class="fixed inset-0 z-50 flex items-center justify-center p-4">
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

          <form class="space-y-4" @submit.prevent="uploadBuildHandler">
            <div class="flex items-start space-x-3">
              <div class="space-y-1">
                <Dialog.Title class="text-lg font-semibold text-gray-900 dark:text-white">
                  Upload new build
                </Dialog.Title>
                <Dialog.Description class="text-sm text-gray-600 dark:text-gray-400">
                  Upload new build for the
                  <span class="text-amber-300">{{ branch.name }}</span> branch
                </Dialog.Description>
              </div>
            </div>

            <div class="space-y-4">
              <div v-if="!success && currentStage === Stage.FillingForm" class="space-y-3">
                <DirectoryUpload class="space-y-1" v-model="dirPath" />

                <SelectOs class="space-y-1" v-model="os" />

                <SelectArch class="space-y-1" v-model="arch" />

                <EntrypointField class="space-y-1" v-model="entrypoint" />

                <div class="space-y-2">
                  <button
                    type="submit"
                    :disabled="!formIsValid"
                    class="inline-flex w-full cursor-pointer items-center justify-center rounded-md bg-gray-900 px-3 py-2 text-sm font-medium text-white transition-colors hover:bg-gray-800 disabled:cursor-not-allowed disabled:bg-gray-100 disabled:text-gray-400 dark:bg-white dark:text-gray-900 dark:hover:bg-gray-100 disabled:dark:bg-gray-800 disabled:dark:text-gray-600"
                  >
                    Upload build
                  </button>
                </div>
              </div>

              <!-- Progress indicator -->
              <div
                v-if="currentStage === Stage.Packing || currentStage === Stage.Uploading"
                class="mt-4 w-full max-w-md"
              >
                <div class="mb-2 flex items-center justify-between">
                  <div class="text-sm text-gray-700 dark:text-gray-300">
                    <span v-if="currentStage === Stage.Packing">Packing...</span>
                    <span v-if="currentStage === Stage.Uploading">Uploading...</span>
                  </div>
                  <span
                    v-if="stageProgress !== 0.0"
                    class="text-sm text-gray-500 dark:text-gray-400"
                  >
                    {{ stageProgress.toFixed(0) }}%
                  </span>
                </div>
                <div class="h-2 w-full overflow-hidden rounded-full bg-gray-200 dark:bg-gray-700">
                  <div
                    class="h-full animate-pulse bg-emerald-500"
                    :style="{ width: `${stageProgress}%` }"
                  ></div>
                </div>
                <small class="text-gray-500">{{ progressDetails }}</small>
              </div>

              <!-- Success message -->
              <div
                v-if="success"
                class="mt-4 rounded bg-green-100 px-4 py-2 text-sm text-green-800 dark:bg-green-900 dark:text-green-200"
              >
                Upload completed successfully!
              </div>

              <!-- Error message -->
              <div
                v-if="error"
                class="mt-4 rounded bg-red-100 px-4 py-2 text-sm text-red-800 dark:bg-red-900 dark:text-red-200"
              >
                Error: {{ error }}
              </div>
            </div>
          </form>
        </Dialog.Content>
      </Dialog.Positioner>
    </Teleport>
  </Dialog.Root>
</template>
