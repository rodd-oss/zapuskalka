<script setup lang="ts">
import { reactive, computed } from 'vue'
import { RouterView } from 'vue-router'
import { Progress as ProgressRoot, ProgressTrack, ProgressRange } from '@ark-ui/vue/progress'

import { check } from '@tauri-apps/plugin-updater'
import { relaunch } from '@tauri-apps/plugin-process'
import { onMounted } from 'vue'

interface UpdateState {
  available: boolean
  status: 'idle' | 'downloading' | 'finished' | 'error'
  progress: number
  version: string
  date?: string
  body?: string
}

// Состояние обновления
const updateState = reactive<UpdateState>({
  available: false,
  status: 'idle',
  progress: 0,
  version: '',
  date: '',
  body: '',
})

// Computed свойства для удобства
const showUpdateUI = computed(() => updateState.available && updateState.status !== 'finished')
const showApp = computed(() => !updateState.available || updateState.status === 'finished')

const startUpdateProcess = async () => {
  try {
    const update = await check()

    if (!update) {
      updateState.available = false
      return
    }

    updateState.available = true
    updateState.version = update.version
    updateState.date = update.date
    updateState.body = update.body
    updateState.status = 'downloading'

    console.log(`found update ${update.version} from ${update.date} with notes ${update.body}`)

    let downloaded = 0
    let contentLength = 0

    await update.downloadAndInstall((event) => {
      switch (event.event) {
        case 'Started':
          if (event.data.contentLength == undefined) {
            throw new Error('Content length undefined')
          }
          contentLength = event.data.contentLength
          console.log(`started downloading ${event.data.contentLength} bytes`)
          break
        case 'Progress':
          downloaded += event.data.chunkLength
          // Обновляем прогресс в процентах
          updateState.progress = Math.round((downloaded / contentLength) * 100)
          console.log(`downloaded ${downloaded} from ${contentLength}`)
          break
        case 'Finished':
          console.log('download finished')
          updateState.status = 'finished'
          break
      }
    })

    console.log('update installed')
    await relaunch()
  } catch (error) {
    console.error('Update failed:', error)
    updateState.status = 'error'
  }
}

onMounted(() => {
  startUpdateProcess()
})
</script>

<template>
  <div v-if="showUpdateUI" class="update-container">
    <div class="update-content">
      <h2>Обновление приложения</h2>
      <p v-if="updateState.version">Версия: {{ updateState.version }}</p>

      <div class="progress-section">
        <ProgressRoot :value="updateState.progress" class="mx-auto w-full max-w-sm">
          <ProgressTrack
            class="h-2 w-full overflow-hidden rounded-full bg-gray-200 dark:bg-gray-700"
          >
            <ProgressRange
              class="h-full rounded-full bg-blue-600 transition-all duration-300 ease-out dark:bg-blue-500"
            />
          </ProgressTrack>
        </ProgressRoot>
        <div class="progress-text">{{ updateState.progress }}%</div>
      </div>

      <div v-if="updateState.status === 'downloading'" class="status">Загрузка обновления...</div>
      <div v-else-if="updateState.status === 'finished'" class="status">
        Обновление установлено! Перезапуск...
      </div>
      <div v-else-if="updateState.status === 'error'" class="status error">
        Ошибка при обновлении
      </div>

      <div v-if="updateState.body" class="update-notes">
        <h3>Что нового:</h3>
        <p>{{ updateState.body }}</p>
      </div>
    </div>
  </div>

  <RouterView v-else-if="showApp" />
</template>

<style scoped>
.update-container {
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 100vh;
  padding: 2rem;
}

.update-content {
  text-align: center;
  max-width: 500px;
  width: 100%;
}

.progress-section {
  margin: 2rem 0;
}

.progress-text {
  margin-top: 0.5rem;
  font-size: 0.875rem;
  color: #6b7280;
}

.status {
  margin: 1rem 0;
  font-weight: 500;
}

.status.err {
  color: #ef4444;
}

.update-notes {
  margin-top: 2rem;
  text-align: left;
}

.update-notes h3 {
  margin-bottom: 0.5rem;
  font-weight: 600;
}

.update-notes p {
  color: #6b7280;
  line-height: 1.5;
}
</style>
