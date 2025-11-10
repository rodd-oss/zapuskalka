<script setup lang="ts">
import Avatar from '@/components/ui/avatar/Avatar.vue'
import AvatarFallback from '@/components/ui/avatar/AvatarFallback.vue'
import AvatarImage from '@/components/ui/avatar/AvatarImage.vue'
import { useAuth } from '@/lib/usePocketbase'

const links = [
  { to: '/', title: 'Home' },
  { to: '/library', title: 'Library' },
  { to: '/settings', title: 'Settings' },
]

const auth = useAuth()
</script>
<template>
  <div class="grid h-screen grid-rows-[56px_1fr]">
    <header
      aria-label="Primary"
      class="sticky top-0 z-50 h-14 w-full border-b border-gray-200 bg-white/70 backdrop-blur supports-backdrop-filter:bg-white/60"
    >
      <nav class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between">
          <div class="flex items-center justify-start">
            <RouterLink
              v-for="link in links"
              :key="link.to"
              :to="link.to"
              class="relative box-content p-3 text-lg font-medium text-gray-700 transition-colors hover:text-gray-900"
              active-class="text-gray-900"
              v-slot="{ isActive }"
            >
              {{ link.title }}
              <div v-if="isActive" class="bg-primary absolute bottom-0 left-0 h-0.5 w-full"></div>
            </RouterLink>
          </div>

          <div class="flex items-center justify-end">
            <RouterLink
              to="/profile"
              class="text-md flex flex-row items-center gap-2 p-3 text-gray-700 transition-colors hover:text-gray-900"
            >
              <div>
                {{ auth.record.value?.name }}
              </div>
              <Avatar>
                <AvatarImage src="https://github.com/unovue.png" alt="@unovue" />
                <AvatarFallback>M</AvatarFallback>
              </Avatar>
            </RouterLink>
          </div>
        </div>
      </nav>
    </header>
    <main class="overflow-hidden">
      <slot id="" />
    </main>
  </div>
</template>
