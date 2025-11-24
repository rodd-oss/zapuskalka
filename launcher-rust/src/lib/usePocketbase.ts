import { computed, onUnmounted, reactive, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import { newApiClient } from 'backend-api'

const apiClient = newApiClient('http://localhost:8090')

const authStore = reactive({
  isSuperuser: apiClient.authStore.isSuperuser,
  isValid: apiClient.authStore.isValid,
  record: apiClient.authStore.record,
  token: apiClient.authStore.token,
})

const unsub = apiClient.authStore.onChange((newToken, newRecord) => {
  authStore.isSuperuser = apiClient.authStore.isSuperuser
  authStore.isValid = apiClient.authStore.isValid
  authStore.record = newRecord
  authStore.token = newToken
})

onUnmounted(unsub)

export const usePocketBase = () => apiClient

export const useAuthenticated = () => {
  const auth = useAuth()
  const router = useRouter()

  watch(auth.isValid, () => {
    if (auth.isValid.value) {
      return
    }

    router.push('/auth')
  })
}

export const useAuth = () => {
  const pb = usePocketBase()

  const loading = ref(false)
  const error = ref<string | null>(null)

  const logout = async () => {
    pb.authStore.clear()
  }

  const authUserWithPassword = async (credentials: { email: string; password: string }) => {
    try {
      loading.value = true
      error.value = null
      await pb.collection('users').authWithPassword(credentials.email, credentials.password)
    } catch (err) {
      error.value = (err as Error).message
    } finally {
      loading.value = false
    }
  }

  const authWithOAuth2 = async (provider: string) => {
    try {
      loading.value = true
      error.value = null
      await pb.collection('users').authWithOAuth2({
        provider: provider,
      })
    } catch (err) {
      error.value = (err as Error).message
    } finally {
      loading.value = false
    }
  }

  const listAuthMethods = async () => {
    const pb = usePocketBase()

    return pb.collection('users').listAuthMethods()
  }

  return {
    isSuperuser: computed(() => authStore.isSuperuser),
    isValid: computed(() => authStore.isValid),
    record: computed(() => authStore.record),
    token: computed(() => authStore.token),
    logout,
    authUserWithPassword,
    authWithOAuth2,
    listAuthMethods,
    loading,
    error,
  }
}
