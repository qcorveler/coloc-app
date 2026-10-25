<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { Notify } from 'quasar'
import { useRoute, useRouter } from 'vue-router'
import { ApiError } from '../lib/api'
import { confirm } from '../lib/confirm'
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
    Notify.create({ message: 'Lien copié' })
  } catch {
    Notify.create({ message: link, timeout: 0, actions: [{ label: 'OK', color: 'white' }] })
  }
}

async function refreshLink() {
  if (!coloc.value || !(await confirm('L’ancien lien ne fonctionnera plus. Continuer ?'))) return
  submitting.value = true
  try {
    coloc.value = await regenerateInvite(coloc.value.id)
    Notify.create({ message: 'Nouveau lien prêt à être copié' })
  } catch (error) {
    errors.value = error instanceof ApiError ? error.errors : ['Impossible de régénérer le lien']
  } finally {
    submitting.value = false
  }
}

async function leave() {
  if (!coloc.value || !(await confirm('Quitter cette coloc ?', 'Quitter', 'negative'))) return
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
  <q-page class="page">
    <div v-if="loading" class="row justify-center q-pa-lg">
      <q-spinner color="primary" size="32px" />
    </div>
    <template v-else-if="coloc">
      <q-img v-if="coloc.photo_url" :src="coloc.photo_url" :alt="coloc.name" :ratio="16 / 9" class="rounded-borders q-mt-sm" />
      <div v-else class="banner-fallback">{{ initial(coloc.name) }}</div>
      <h1 class="text-h4 q-mt-md q-mb-sm">{{ coloc.name }}</h1>
      <p class="muted">{{ coloc.address }}</p>
      <p class="q-my-md">{{ coloc.description || 'Pas encore de description.' }}</p>
      <p class="muted q-mb-sm">{{ coloc.member_count }} / 30</p>
      <q-list dense class="q-mb-md">
        <q-item v-for="member in coloc.members" :key="member.id">
          <q-item-section>{{ member.first_name }} {{ member.last_name }}</q-item-section>
        </q-item>
      </q-list>
      <div class="column q-gutter-sm">
        <q-btn color="primary" unelevated no-caps label="Planning" :to="`/colocs/${coloc.id}/planning`" />
        <q-btn color="primary" unelevated no-caps label="Copier le lien d’invitation" :disable="submitting" @click="copyLink" />
        <q-btn outline no-caps color="primary" label="Régénérer le lien" :disable="submitting" @click="refreshLink" />
        <q-btn outline no-caps color="primary" label="Modifier" :to="`/colocs/${coloc.id}/modifier`" />
        <q-btn outline no-caps color="negative" label="Quitter" :disable="submitting" @click="leave" />
      </div>
    </template>
    <q-banner v-if="errors.length" class="bg-negative text-white q-mt-md" rounded>
      <div v-for="(message, index) in errors" :key="index">{{ message }}</div>
    </q-banner>
    <q-btn flat no-caps color="primary" class="q-mt-lg" label="Mes colocs" to="/" />
  </q-page>
</template>
