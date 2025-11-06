<script setup lang="ts">
import { useAuth } from '@/lib/usePocketbase'

const links = [
  { to: '/store', title: 'Store' },
  { to: '/library', title: 'Library' },
]

const auth = useAuth()
</script>
<template>
  <header
    aria-label="Primary"
    class="sticky top-0 z-50 w-full border-b border-gray-200 bg-white/70 backdrop-blur supports-backdrop-filter:bg-white/60"
  >
    <nav class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
      <div class="flex h-14 justify-between">
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
            class="text-md p-3 text-gray-700 transition-colors hover:text-gray-900"
          >
            {{ auth.record.value?.name }}
          </RouterLink>
        </div>
      </div>
    </nav>
  </header>
  <main class="mx-auto max-w-7xl px-8 py-4 sm:px-10 lg:px-12">
    <slot id="" />
  </main>
</template>
