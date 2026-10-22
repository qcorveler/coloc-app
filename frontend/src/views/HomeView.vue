<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '../composables/useAuth'

const router = useRouter()
const { user, logout } = useAuth()
const submitting = ref(false)

async function onLogout() {
  submitting.value = true
  try {
    await logout()
    await router.push('/login')
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <main class="screen">
    <h1>Salut {{ user?.first_name }}</h1>
    <p class="lead">La coloc arrive bientôt. En attendant, ton compte est prêt.</p>
    <button type="button" class="secondary" :disabled="submitting" @click="onLogout">
      Se déconnecter
    </button>
  </main>
</template>
