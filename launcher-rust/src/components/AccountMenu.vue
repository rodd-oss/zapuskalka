<script setup lang="ts">
import { useAuth } from '@/lib/usePocketbase'
import { Avatar } from '@ark-ui/vue'
import { Menu } from '@ark-ui/vue/menu'
import { ChevronDown, LogOut } from 'lucide-vue-next'

const auth = useAuth()

async function onLogOutHandler() {
  try {
    await auth.logout()
  } catch (err) {
    console.error(err)
  }
}
</script>

<template>
  <Menu.Root>
    <Menu.Trigger
      class="inline-flex items-center gap-3 rounded-lg border border-gray-200 bg-white px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 focus:ring-2 focus:ring-gray-900 focus:ring-offset-2 focus:outline-hidden dark:border-gray-700 dark:bg-gray-900 dark:text-gray-300 dark:hover:bg-gray-800 dark:focus:ring-gray-100"
    >
      <Avatar.Root class="h-6 w-6">
        <Avatar.Fallback
          class="flex h-full w-full items-center justify-center rounded-full bg-linear-to-br from-blue-500 to-purple-600 text-xs font-semibold text-white"
        >
          {{ auth.user.value?.name?.charAt(0) }}
        </Avatar.Fallback>
        <Avatar.Image
          :src="auth.avatarURL.value"
          alt="avatar"
          class="h-full w-full rounded-full object-cover"
        />
      </Avatar.Root>
      <span>{{ auth.user.value?.name }}</span>
      <ChevronDown class="h-4 w-4" />
    </Menu.Trigger>
    <Teleport to="body">
      <Menu.Positioner>
        <Menu.Content
          class="z-50 min-w-56 rounded-lg border border-gray-200 bg-white p-1 shadow-lg focus-visible:outline-hidden dark:border-gray-700 dark:bg-gray-900"
        >
          <div class="border-b border-gray-200 px-3 py-2 dark:border-gray-700">
            <div class="text-sm font-medium text-gray-900 dark:text-gray-100">
              {{ auth.user.value?.name }}
            </div>
            <div class="text-xs text-gray-500 dark:text-gray-400">{{ auth.user.value?.email }}</div>
          </div>
          <!-- <Menu.Item
            value="profile"
            class="flex cursor-pointer items-center gap-3 rounded-md px-3 py-2 text-sm text-gray-700 hover:bg-gray-100 focus:bg-gray-100 dark:text-gray-300 dark:hover:bg-gray-800 dark:focus:bg-gray-800"
          >
            <User class="h-4 w-4" />
            Profile
          </Menu.Item>
          <Menu.Item
            value="settings"
            class="flex cursor-pointer items-center gap-3 rounded-md px-3 py-2 text-sm text-gray-700 hover:bg-gray-100 focus:bg-gray-100 dark:text-gray-300 dark:hover:bg-gray-800 dark:focus:bg-gray-800"
          >
            <Settings class="h-4 w-4" />
            Settings
          </Menu.Item>
          <Menu.Item
            value="billing"
            class="flex cursor-pointer items-center gap-3 rounded-md px-3 py-2 text-sm text-gray-700 hover:bg-gray-100 focus:bg-gray-100 dark:text-gray-300 dark:hover:bg-gray-800 dark:focus:bg-gray-800"
          >
            <CreditCard class="h-4 w-4" />
            Billing
          </Menu.Item>
          <Menu.Separator class="my-1 h-px border-gray-200 dark:border-gray-700" />
          <Menu.Item
            value="help"
            class="flex cursor-pointer items-center gap-3 rounded-md px-3 py-2 text-sm text-gray-700 hover:bg-gray-100 focus:bg-gray-100 dark:text-gray-300 dark:hover:bg-gray-800 dark:focus:bg-gray-800"
          >
            <HelpCircle class="h-4 w-4" />
            Help & Support
          </Menu.Item>
          <Menu.Separator class="my-1 h-px border-gray-200 dark:border-gray-700" /> -->
          <Menu.Item
            value="logout"
            class="flex cursor-pointer items-center gap-3 rounded-md px-3 py-2 text-sm text-red-600 hover:bg-red-50 focus:bg-red-50 dark:text-red-400 dark:hover:bg-red-900/20 dark:focus:bg-red-900/20"
            @click="onLogOutHandler"
          >
            <LogOut class="h-4 w-4" />
            Log out
          </Menu.Item>
        </Menu.Content>
      </Menu.Positioner>
    </Teleport>
  </Menu.Root>
</template>
