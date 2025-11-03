import PocketBase from 'pocketbase'
import { computed, onUnmounted, reactive, ref, readonly } from 'vue'

const pbClient = new PocketBase('http://localhost:8090')

export const usePocketBase = () => pbClient

export const useAuth = () => {
  const pb = usePocketBase()

  const isSuperuser = ref(pb.authStore.isSuperuser)
  const isValid = ref(pb.authStore.isValid)
  const record = ref(pb.authStore.record)
  const token = ref(pb.authStore.token)
  const loading = ref(false)
  const error = ref<string | null>(null)

  const unsub = pb.authStore.onChange((newToken, newRecord) => {
    isSuperuser.value = pb.authStore.isSuperuser
    isValid.value = pb.authStore.isValid
    record.value = newRecord
    token.value = newToken
  })

  onUnmounted(unsub)

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
    isSuperuser: readonly(isSuperuser),
    isValid: readonly(isValid),
    record: readonly(record),
    token: readonly(token),
    logout,
    authUserWithPassword,
    authWithOAuth2,
  }
}
