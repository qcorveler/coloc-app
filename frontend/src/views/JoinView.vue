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
  <q-page class="page">
    <div v-if="loading" class="row justify-center q-pa-lg">
      <q-spinner color="primary" size="32px" />
    </div>
    <template v-else-if="coloc">
      <q-img v-if="coloc.photo_url" :src="coloc.photo_url" :alt="coloc.name" :ratio="16 / 9" class="rounded-borders q-mt-sm" />
      <div v-else class="banner-fallback">{{ initial(coloc.name) }}</div>
      <h1 class="text-h4 q-mt-md q-mb-sm">{{ coloc.name }}</h1>
      <p class="muted">{{ coloc.address }}</p>
      <p class="q-my-md">{{ coloc.member_count }} / 30 personnes</p>
      <q-btn color="primary" unelevated no-caps class="full-width" label="Rejoindre" :loading="submitting" @click="join" />
    </template>
    <q-banner v-if="errors.length" class="bg-negative text-white q-mt-md" rounded>
      <div v-for="(message, index) in errors" :key="index">{{ message }}</div>
    </q-banner>
  </q-page>
</template>
