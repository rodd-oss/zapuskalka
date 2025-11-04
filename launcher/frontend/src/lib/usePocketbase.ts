import PocketBase from 'pocketbase'
import { computed, onUnmounted, reactive, ref, readonly } from 'vue'

const pbClient = new PocketBase('http://localhost:8090')

const authStore = reactive({
  isSuperuser: pbClient.authStore.isSuperuser,
  isValid: pbClient.authStore.isValid,
  record: pbClient.authStore.record,
  token: pbClient.authStore.token,
})

const unsub = pbClient.authStore.onChange((newToken, newRecord) => {
  authStore.isSuperuser = pbClient.authStore.isSuperuser
  authStore.isValid = pbClient.authStore.isValid
  authStore.record = newRecord
  authStore.token = newToken
})

onUnmounted(unsub)

export const usePocketBase = () => pbClient

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

  return {
    isSuperuser: computed(() => authStore.isSuperuser),
    isValid: computed(() => authStore.isValid),
    record: computed(() => authStore.record),
    token: computed(() => authStore.token),
    logout,
    authUserWithPassword,
    authWithOAuth2,
  }
}
