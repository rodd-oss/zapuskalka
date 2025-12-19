import { computed, onUnmounted, reactive, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import { newApiClient, type UsersResponse } from 'backend-api'

const apiClient = newApiClient(import.meta.env.VITE_BACKEND_URL || 'http://localhost:8090')

const user = ref<UsersResponse | null>(apiClient.authStore.record as unknown as UsersResponse)

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
  user.value = newRecord as unknown as UsersResponse
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

  const loading = ref<boolean>(false)
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

  const avatarURL = computed(() => {
    if (user.value == null) {
      return undefined
    }

    if (user.value.avatar == undefined) {
      return undefined
    }

    return pb.files.getURL(user.value, user.value.avatar)
  })

  return {
    isSuperuser: computed(() => authStore.isSuperuser),
    isValid: computed(() => authStore.isValid),
    record: computed(() => authStore.record),
    token: computed(() => authStore.token),
    user: user,
    avatarURL: avatarURL,
    logout,
    authUserWithPassword,
    authWithOAuth2,
    listAuthMethods,
    loading,
    error,
  }
}
