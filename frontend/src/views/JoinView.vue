<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ApiError } from '../lib/api'
import { fetchInvitation, initial, joinColoc, type ColocSummary } from '../lib/colocs'

const route = useRoute()
const router = useRouter()
const coloc = ref<ColocSummary | null>(null)
const errors = ref<string[]>([])
const loading = ref(true)
const submitting = ref(false)

onMounted(async () => {
  try {
    coloc.value = await fetchInvitation(String(route.params.token))
  } catch (error) {
    errors.value = error instanceof ApiError ? error.errors : ['Cette invitation est introuvable']
  } finally {
    loading.value = false
  }
})

async function join() {
  errors.value = []
  submitting.value = true
  try {
    const joined = await joinColoc(String(route.params.token))
    await router.push(`/colocs/${joined.id}`)
  } catch (error) {
    errors.value = error instanceof ApiError ? error.errors : ['Impossible de rejoindre la coloc']
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <main class="screen">
    <p v-if="loading" class="lead">Chargement…</p>
    <template v-else-if="coloc">
      <img v-if="coloc.photo_url" :src="coloc.photo_url" :alt="coloc.name" class="banner" />
      <div v-else class="banner fallback">{{ initial(coloc.name) }}</div>
      <h1>{{ coloc.name }}</h1>
      <p class="muted">{{ coloc.address }}</p>
      <p class="lead">{{ coloc.member_count }} / 30 personnes</p>
      <button type="button" :disabled="submitting" @click="join">Rejoindre</button>
    </template>
    <ul v-if="errors.length" class="errors">
      <li v-for="(message, index) in errors" :key="index">{{ message }}</li>
    </ul>
  </main>
</template>
