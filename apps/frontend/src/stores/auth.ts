import { ref, computed } from 'vue'
import { defineStore } from 'pinia'
import { ClientResponseError, type AuthMethodsList } from 'pocketbase'
import { pb } from '@/lib/pocketbase'
import type { UsersResponse } from 'backend-api'

export const useAuthStore = defineStore('auth', () => {
  const user = ref<UsersResponse | null>(null)
  const token = ref<string>('')
  const isLoading = ref(false)
  const error = ref<string | null>(null)
  const authMethods = ref<AuthMethodsList | null>(null)

  const isAuthenticated = computed(() => !!token.value && !!user.value)

  async function getAuthMethods(): Promise<void> {
    try {
      const methods = await pb.collection('users').listAuthMethods()
      authMethods.value = methods
    } catch (err) {
      console.error('[AuthStore] Failed to fetch auth methods:', err)
      authMethods.value = null
    }
  }

  async function genAuthCode(): Promise<string> {
    if (user.value == null) {
      throw Error('User undefined. Should not call this function if not authenticated.')
    }

    const authCode = await pb.collection('_authCode').create({
      user: user.value.id,
    })
    return authCode.id
  }

  function setAuthData(authUser: UsersResponse | null, authToken: string): void {
    user.value = authUser
    token.value = authToken
  }

  async function login(email: string, password: string): Promise<boolean> {
    isLoading.value = true
    error.value = null

    try {
      const authData = await pb.collection('users').authWithPassword(email, password)
      setAuthData(authData.record, authData.token)
      return true
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Login failed'
      error.value = message
      return false
    } finally {
      isLoading.value = false
    }
  }

  async function authenticateWithOAuth2Code(
    provider: string,
    code: string,
    codeVerifier: string,
    redirectURL: string,
  ): Promise<boolean> {
    isLoading.value = true
    error.value = null

    try {
      const authData = await pb
        .collection('users')
        .authWithOAuth2Code(provider, code, codeVerifier, redirectURL)
      setAuthData(authData.record, authData.token)
      return true
    } catch (err) {
      const message = err instanceof Error ? err.message : 'OAuth authentication failed'
      error.value = message
      return false
    } finally {
      isLoading.value = false
    }
  }

  function clearError() {
    error.value = null
  }

  function logout() {
    pb.authStore.clear()
    setAuthData(null, '')
  }

  async function refreshAuth() {
    if (pb.authStore.isValid) {
      try {
        const authData = await pb.collection('users').authRefresh()
        setAuthData(authData.record, authData.token)
      } catch (err) {
        if (err instanceof ClientResponseError) {
          if (err.status === 401 || err.status === 403) {
            error.value = 'Session expired. Please log in again.'
            logout()
          }
        }
      }
    } else {
      logout()
    }
  }

  function $reset(): void {
    user.value = null
    token.value = ''
    isLoading.value = false
    error.value = null
    authMethods.value = null
  }

  return {
    user,
    token,
    isLoading,
    error,
    authMethods,
    isAuthenticated,
    getAuthMethods,
    genAuthCode,
    clearError,
    login,
    authenticateWithOAuth2Code,
    logout,
    refreshAuth,
    $reset,
  }
})
