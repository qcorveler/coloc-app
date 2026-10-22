<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ApiError } from '../lib/api'
import {
  fetchColoc,
  initial,
  inviteLink,
  leaveColoc,
  regenerateInvite,
  type Coloc,
} from '../lib/colocs'

const route = useRoute()
const router = useRouter()
const coloc = ref<Coloc | null>(null)
const errors = ref<string[]>([])
const notice = ref('')
const loading = ref(true)
const submitting = ref(false)

onMounted(load)

async function load() {
  loading.value = true
  errors.value = []
  try {
    coloc.value = await fetchColoc(String(route.params.id))
  } catch (error) {
    errors.value = error instanceof ApiError ? error.errors : ['Impossible de charger la coloc']
  } finally {
    loading.value = false
  }
}

async function copyLink() {
  if (!coloc.value) return
  const link = inviteLink(coloc.value.invite_token)
  try {
    await navigator.clipboard.writeText(link)
    notice.value = 'Lien copié'
  } catch {
    notice.value = link
  }
}

async function refreshLink() {
  if (!coloc.value || !window.confirm('L’ancien lien ne fonctionnera plus. Continuer ?')) return
  submitting.value = true
  notice.value = ''
  try {
    coloc.value = await regenerateInvite(coloc.value.id)
    notice.value = 'Nouveau lien prêt à être copié'
  } catch (error) {
    errors.value = error instanceof ApiError ? error.errors : ['Impossible de régénérer le lien']
  } finally {
    submitting.value = false
  }
}

async function leave() {
  if (!coloc.value || !window.confirm('Quitter cette coloc ?')) return
  submitting.value = true
  try {
    await leaveColoc(coloc.value.id)
    await router.push('/')
  } catch (error) {
    errors.value = error instanceof ApiError ? error.errors : ['Impossible de quitter la coloc']
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
      <p class="lead">{{ coloc.description || 'Pas encore de description.' }}</p>
      <p class="muted">{{ coloc.member_count }} / 30</p>
      <ul class="members">
        <li v-for="member in coloc.members" :key="member.id">
          {{ member.first_name }} {{ member.last_name }}
        </li>
      </ul>
      <p v-if="notice" class="notice">{{ notice }}</p>
      <div class="actions">
        <button type="button" :disabled="submitting" @click="copyLink">Copier le lien d’invitation</button>
        <button type="button" class="secondary" :disabled="submitting" @click="refreshLink">
          Régénérer le lien
        </button>
        <RouterLink class="button secondary" :to="`/colocs/${coloc.id}/modifier`">Modifier</RouterLink>
        <button type="button" class="secondary" :disabled="submitting" @click="leave">Quitter</button>
      </div>
    </template>
    <ul v-if="errors.length" class="errors">
      <li v-for="(message, index) in errors" :key="index">{{ message }}</li>
    </ul>
    <p class="switch"><RouterLink to="/">Mes colocs</RouterLink></p>
  </main>
</template>
