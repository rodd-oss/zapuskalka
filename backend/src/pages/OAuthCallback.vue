<script setup lang="ts">
import { onMounted, ref } from 'vue';
import usePocketBase from '../lib/usePocketbase';
import type { AuthProviderInfo, RecordAuthResponse, RecordModel } from 'pocketbase';

const props = defineProps<{
  code?: string;
  scope?: string;
  state?: string;
}>();

const pb = usePocketBase();

const authData = ref<RecordAuthResponse<RecordModel> | null>(null);
const error = ref<string | null>(null);
const isLoading = ref(true);
const link = ref<string>();

async function handleOAuthCallback() {
  const providerData = localStorage.getItem('provider');
  
  if (!providerData) {
    error.value = 'Provider data not found';
    isLoading.value = false;
    return;
  }

  const provider = JSON.parse(providerData) as AuthProviderInfo;
  const redirectUri = `${window.location.origin}/oauth/${provider.name}/callback`;

  if (provider.state !== props.state) {
    error.value = 'Invalid state parameter';
    isLoading.value = false;
    return;
  }

  if (!props.code) {
    error.value = 'Authorization code not provided';
    isLoading.value = false;
    return;
  }

  try {
    authData.value = await pb.collection('users').authWithOAuth2Code(
      provider.name,
      props.code,
      provider.codeVerifier,
      redirectUri
    );
    
    localStorage.removeItem('provider');
    
    const params = new URLSearchParams({
      token: authData.value.token,
      record: JSON.stringify(authData.value.record),
    });
    
    link.value = `zapuskalka://auth?${params.toString()}`;
  } catch (err) {
    error.value = err instanceof Error ? err.message : 'Authentication failed';
  } finally {
    isLoading.value = false;
  }
}

onMounted(() => {
  handleOAuthCallback();
});
</script>
<template>
  <UMain>
    <div class="flex min-h-svh w-full items-center justify-center p-6 md:p-10">
      <UPageCard class="w-full max-w-md">
        <template v-if="isLoading">
          <div class="flex items-center justify-center py-8">
            <UIcon name="i-heroicons-arrow-path" class="h-8 w-8 animate-spin" />
            <span class="ml-2">Authenticating...</span>
          </div>
        </template>
        
        <template v-else-if="error">
          <div class="text-center text-red-500">
            <UIcon name="i-heroicons-exclamation-circle" class="h-8 w-8 mx-auto mb-2" />
            <p>{{ error }}</p>
          </div>
        </template>
        
        <template v-else>
          <div class="text-center text-green-500">
            <UIcon name="i-heroicons-check-circle" class="h-8 w-8 mx-auto mb-2" />
            <p>Successfully authenticated!</p>
            <UButton
              class="mt-4"
              color="primary"
              :to="link"
            >Continue to App</UButton>
          </div>
        </template>
      </UPageCard>
    </div>
  </UMain>
</template>
