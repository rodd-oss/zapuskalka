<script setup lang="ts">
import { open } from '@tauri-apps/plugin-dialog'
import { Channel, invoke } from '@tauri-apps/api/core'
import { usePocketBase } from '@/lib/usePocketbase'
import { ref } from 'vue'
import {
  AppBranchesResponse,
  AppBuildsArchOptions,
  AppBuildsInstallRulesOptions,
  AppBuildsOsOptions,
  AppsResponse,
  Collections,
  Create,
} from 'backend-api'

const pb = usePocketBase()
const uploading = ref(false)
const uploadProgress = ref(0)
const error = ref<string | null>(null)
const success = ref(false)

const props = defineProps<{ app: AppsResponse; branch: AppBranchesResponse }>()

const selectFolder = async () => {
  try {
    error.value = null
    success.value = false
    uploadProgress.value = 0

    const appRootFolder = await open({
      title: 'Select folder with your exported app',
      multiple: false,
      directory: true,
    })

    if (!appRootFolder) {
      return
    }

    uploading.value = true

    // Step 1: Archive and compress the folder using Rust
    const archivePath = await invoke<string>('archive_and_compress_folder', {
      folderPath: appRootFolder,
    })

    const data: Create<Collections.AppBuilds> = {
      app: props.app.id,
      branch: props.branch.id,
      os: AppBuildsOsOptions.macos,
      arch: AppBuildsArchOptions.universal,
      install_rules: [
        AppBuildsInstallRulesOptions.direct_copy,
        AppBuildsInstallRulesOptions.untar,
        AppBuildsInstallRulesOptions.ungzip,
      ],
      entrypoint: 'gigabah.app',
    }

    const buildRecord = await pb.collection('app_builds').create(data)
    console.log('build record' + buildRecord)

    const url = `${pb.baseURL}/api/collections/app_builds/records/${buildRecord.id}`
    // await upload(
    //   url,
    //   archivePath,
    //   ({ progress, total }) => console.log(`Uploaded ${progress} of ${total} bytes`), // a callback that will be called with the upload progress
    //   new Map().set('Content-Type', 'multipart/form-data'), // optional headers to send with the request
    // )

    interface ProgressPayload {
      progress: number
      total: number
      transfer_speed: number
    }

    const onProgress = new Channel<ProgressPayload>()
    onProgress.onmessage = ({ progress, total, transfer_speed }: ProgressPayload) => {
      uploadProgress.value = total > 0 ? Math.round((progress / total) * 100) : 0
      console.log(`speed ${transfer_speed} Uploaded ${progress} of ${total} bytes`)
    }

    // Use custom Rust function that properly creates multipart/form-data with "files" field
    // This ensures correct boundary and field name for PocketBase
    await invoke('upload_file_as_form_data', {
      url,
      filePath: archivePath,
      authToken: pb.authStore.token || null,
      progressChannel: onProgress,
    })

    // // Step 2: Read the file and prepare for upload
    // // Read the file as binary using Rust command
    // const fileDataArray = await invoke<number[]>('read_file_bytes', {
    //   filePath: archivePath,
    // })

    // // Convert number array to Uint8Array
    // const fileData = new Uint8Array(fileDataArray)

    // // Get the filename from the path
    // const fileName = archivePath.split(/[/\\]/).pop() || 'archive.tar.gz'

    // // Create a File instance from the binary data
    // const file = new File([fileData], fileName, { type: 'application/gzip' })

    // // Step 3: Upload to PocketBase using the SDK's create method
    // // Note: The app_builds collection requires additional fields (app, os, arch, entrypoint, install_rules)
    // // For now, we'll just upload the file. You may want to add UI for these fields later.
    // const formData = new FormData()
    // formData.append('files', file)

    // // Upload using PocketBase SDK (following the example pattern)
    // // Note: Progress tracking is not available with the SDK's create method
    // // The SDK handles authentication automatically via pb.authStore
    // await pb.collection('app_builds').create(formData)

    success.value = true
    uploadProgress.value = 100
  } catch (err) {
    error.value = err instanceof Error ? err.message : 'Unknown error occurred'
    console.error('Upload error:', err)
  } finally {
    uploading.value = false
  }
}
</script>
<template>
  <div class="flex w-full flex-col items-center rounded-xl bg-white px-4 py-12 dark:bg-gray-800">
    <label class="flex flex-col gap-2 rounded-xl bg-white px-6 py-4 dark:bg-gray-700">
      Select folder with your exported app
      <button
        class="cursor-pointer rounded bg-emerald-500 p-2 text-amber-50 hover:bg-emerald-400 disabled:cursor-not-allowed disabled:opacity-50"
        @click="selectFolder"
        :disabled="uploading"
      >
        {{ uploading ? 'Processing...' : 'Browse' }}
      </button>
    </label>

    <!-- Progress indicator -->
    <div v-if="uploading" class="mt-4 w-full max-w-md">
      <div class="mb-2 text-sm text-gray-600 dark:text-gray-400">Processing and uploading...</div>
      <div class="h-2 w-full overflow-hidden rounded-full bg-gray-200 dark:bg-gray-700">
        <div class="h-full w-full animate-pulse bg-emerald-500"></div>
      </div>
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
</template>
