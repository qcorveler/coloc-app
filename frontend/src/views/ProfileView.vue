<script setup lang="ts">
import { ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import { ApiError } from '../lib/api'
import { parseLocal } from '../lib/dates'
import { initial } from '../lib/colocs'
import { fetchProfile, type Profile } from '../lib/profiles'

const route = useRoute()
const profile = ref<Profile | null>(null)
const errors = ref<string[]>([])
const loading = ref(true)

watch(
  () => [route.params.id, route.params.userId],
  () => {
    void load()
  },
  { immediate: true },
)

async function load() {
  const colocId = String(route.params.id)
  const userId = String(route.params.userId)
  loading.value = true
  errors.value = []
  try {
    const next = await fetchProfile(colocId, userId)
    if (!sameRoute(colocId, userId)) return
    profile.value = next
  } catch (error) {
    if (!sameRoute(colocId, userId)) return
    profile.value = null
    errors.value = error instanceof ApiError ? error.errors : ['Impossible de charger le profil']
  } finally {
    if (sameRoute(colocId, userId)) loading.value = false
  }
}

function sameRoute(colocId: string, userId: string) {
  return colocId === String(route.params.id) && userId === String(route.params.userId)
}

function formatDate(iso: string) {
  return new Intl.DateTimeFormat('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' }).format(parseLocal(iso))
}
</script>

<template>
  <q-page class="page">
    <div v-if="loading" class="row justify-center q-pa-lg">
      <q-spinner color="primary" size="32px" />
    </div>
    <template v-else-if="profile">
      <div class="column items-center">
        <q-avatar v-if="profile.avatar_url" size="96px">
          <img :src="profile.avatar_url" :alt="profile.first_name" />
        </q-avatar>
        <q-avatar v-else size="96px" color="primary" text-color="white" class="text-h4">
          {{ initial(profile.first_name) }}
        </q-avatar>
        <h1 class="text-h5 q-mt-md q-mb-none">{{ profile.first_name }} {{ profile.last_name }}</h1>
        <p v-if="profile.pronouns" class="muted q-mt-xs q-mb-none">{{ profile.pronouns }}</p>
      </div>
      <p class="q-mt-lg q-mb-none" :class="{ muted: !profile.mood }">{{ profile.mood || 'Pas encore d’humeur.' }}</p>
      <p class="q-my-md" :class="{ muted: !profile.description }">{{ profile.description || 'Pas encore de description.' }}</p>
      <p class="muted q-mb-xs">Arrivée le {{ formatDate(profile.arrived_on) }}</p>
      <p class="muted q-my-none">Anniversaire le {{ formatDate(profile.date_of_birth) }}</p>
    </template>
    <q-banner v-if="errors.length" class="bg-negative text-white q-mt-md" rounded>
      <div v-for="(message, index) in errors" :key="index">{{ message }}</div>
    </q-banner>
  </q-page>
</template>
