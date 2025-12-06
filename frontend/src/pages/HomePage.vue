<script setup lang="ts">
import { env } from '@/lib/env'
import { getObjectKeys } from '@/lib/getObjectKeys'
import type { Asset, Release } from '@/types/GitHub'
import axios, { AxiosError } from 'axios'
import { ref } from 'vue'

const release = ref<Release>()
const error = ref<AxiosError>()

const assets = ref({
  exe: {
    name: 'Windows',
    link: '',
  },
  dmg: {
    name: 'Mac',
    link: '',
  },
  deb: {
    name: 'Linux .deb',
    link: '',
  },
  rpm: {
    name: 'Linux .rpm',
    link: '',
  },
})

const fetchAssets = async () => {
  try {
    const { data } = await axios<Release>({
      url: `https://api.github.com/repos/${env.VITE_GIT_SHORT_LINK}/releases/latest`,
    })

    data.assets.forEach((asset: Asset) => {
      getObjectKeys(assets.value).forEach((ext) => {
        if (asset.name.endsWith(`.${ext}`)) {
          assets.value[ext].link = asset.browser_download_url
        }
      })
    })
    release.value = data
  } catch (e) {
    error.value = e as AxiosError
  }
}

fetchAssets()
</script>
<template>
  <div class="flex justify-center items-center w-full h-screen">
    <div v-if="release" class="flex gap-2 items-center flex-col">
      <h1 class="text-6xl relative">
        Zapuskalka

        <span class="text-sm absolute top-0">{{ release.tag_name.replace('app-', '') }}</span>
      </h1>
      <p class="max-w-xl text-center">
        Modern open-source launcher designed for indie game players and developers. The project
        combines the ease of use of Steam with the open distribution model of itch.io, providing a
        free and fair platform for indie content distribution
      </p>
      <div class="flex flex-col gap-2 mt-4">
        <div class="flex gap-2 *:justify-center *:w-full *:whitespace-nowrap">
          <UButton
            v-for="asset in assets"
            :key="asset.name"
            size="xl"
            variant="outline"
            color="neutral"
            :href="asset.link"
            >{{ asset.name }}</UButton
          >
        </div>
      </div>
    </div>
    <div v-if="error">
      {{ error.message }}
    </div>
  </div>
</template>
