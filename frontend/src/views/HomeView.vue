<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '../composables/useAuth'
import { ApiError } from '../lib/api'
import { initial, listColocs, type ColocSummary } from '../lib/colocs'

const router = useRouter()
const { user, logout } = useAuth()
const colocs = ref<ColocSummary[]>([])
const loading = ref(true)
const errors = ref<string[]>([])
const submitting = ref(false)

onMounted(async () => {
  try {
    colocs.value = await listColocs()
  } catch (error) {
    errors.value = error instanceof ApiError ? error.errors : ['Impossible de charger tes colocs']
  } finally {
    loading.value = false
  }
})

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
    <p v-if="loading" class="lead">Chargement…</p>
    <template v-else>
      <p v-if="colocs.length === 0" class="lead">Tu n'as pas encore de coloc.</p>
      <ul v-else class="coloc-list">
        <li v-for="coloc in colocs" :key="coloc.id">
          <RouterLink class="coloc-card" :to="`/colocs/${coloc.id}`">
            <img v-if="coloc.photo_url" :src="coloc.photo_url" alt="" class="thumb" />
            <span v-else class="thumb fallback">{{ initial(coloc.name) }}</span>
            <span>
              <strong>{{ coloc.name }}</strong>
              <span class="muted">{{ coloc.address }}</span>
            </span>
          </RouterLink>
        </li>
      </ul>
      <ul v-if="errors.length" class="errors">
        <li v-for="(message, index) in errors" :key="index">{{ message }}</li>
      </ul>
      <RouterLink class="button" to="/colocs/nouvelle">Créer une coloc</RouterLink>
    </template>
    <button type="button" class="secondary" :disabled="submitting" @click="onLogout">
      Se déconnecter
    </button>
  </main>
</template>
