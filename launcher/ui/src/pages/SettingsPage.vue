<script setup lang="ts">
import BaseLayout from '@/layouts/BaseLayout.vue'
import { useAuthenticated } from '@/lib/usePocketbase'
import Menu from 'primevue/menu'
import type { MenuItem } from 'primevue/menuitem'
import { ref } from 'vue'
import { RouterLink, RouterView } from 'vue-router'

useAuthenticated()

const items = ref<MenuItem[]>([
  {
    label: 'Account',
    route: '/settings/account',
  },
  {
    label: 'Storage',
    route: '/settings/storage',
  },
])
</script>
<template>
  <BaseLayout>
    <div class="grid h-full grid-cols-[max-content_1fr]">
      <Menu :model="items" class="">
        <template #item="{ item, props }">
          <RouterLink v-if="item.route" v-slot="{ href, navigate }" :to="item.route" custom>
            <a v-ripple :href="href" v-bind="props.action" @click="navigate">
              <span :class="item.icon" />
              <span class="ml-2">{{ item.label }}</span>
            </a>
          </RouterLink>
          <a v-else v-ripple :href="item.url" :target="item.target" v-bind="props.action">
            <span :class="item.icon" />
            <span class="ml-2">{{ item.label }}</span>
          </a>
        </template>
      </Menu>
      <div>
        <RouterView />
      </div>
    </div>
  </BaseLayout>
</template>
<style scoped></style>
