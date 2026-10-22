import { ref } from 'vue'
import { api, type User } from '../lib/api'

const user = ref<User | null>(null)
const loading = ref(true)

let loaded: Promise<void> | null = null

export type SignupPayload = {
  email: string
  password: string
  password_confirmation: string
  first_name: string
  last_name: string
  date_of_birth: string
}

export function useAuth() {
  async function fetchCurrentUser() {
    try {
      const data = await api<{ user: User }>('/api/session')
      user.value = data.user
    } catch {
      user.value = null
    } finally {
      loading.value = false
    }
  }

  function ensureLoaded() {
    loaded ??= fetchCurrentUser()
    return loaded
  }

  async function signup(payload: SignupPayload) {
    const data = await api<{ user: User }>('/api/users', {
      method: 'POST',
      body: JSON.stringify({ user: payload }),
    })
    user.value = data.user
  }

  async function login(email: string, password: string) {
    const data = await api<{ user: User }>('/api/session', {
      method: 'POST',
      body: JSON.stringify({ email, password }),
    })
    user.value = data.user
  }

  async function logout() {
    await api<void>('/api/session', { method: 'DELETE' })
    user.value = null
  }

  return { user, loading, ensureLoaded, signup, login, logout }
}
