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
  <q-page class="page">
    <h1 class="text-h4 q-mt-md q-mb-lg">Salut {{ user?.first_name }}</h1>
    <div v-if="loading" class="row justify-center q-pa-lg">
      <q-spinner color="primary" size="32px" />
    </div>
    <template v-else>
      <p v-if="colocs.length === 0" class="q-mb-lg">Tu n'as pas encore de coloc.</p>
      <q-list v-else bordered separator class="rounded-borders q-mb-lg">
        <q-item v-for="coloc in colocs" :key="coloc.id" clickable :to="`/colocs/${coloc.id}`">
          <q-item-section avatar>
            <q-avatar v-if="coloc.photo_url" size="64px" rounded>
              <img :src="coloc.photo_url" alt="" />
            </q-avatar>
            <q-avatar v-else size="64px" rounded color="primary" text-color="white">
              {{ initial(coloc.name) }}
            </q-avatar>
          </q-item-section>
          <q-item-section>
            <q-item-label>{{ coloc.name }}</q-item-label>
            <q-item-label caption>{{ coloc.address }}</q-item-label>
          </q-item-section>
        </q-item>
      </q-list>
      <q-banner v-if="errors.length" class="bg-negative text-white q-mb-md" rounded>
        <div v-for="(message, index) in errors" :key="index">{{ message }}</div>
      </q-banner>
      <q-btn color="primary" unelevated no-caps class="full-width" label="Créer une coloc" to="/colocs/nouvelle" />
    </template>
    <q-btn
      outline
      no-caps
      color="primary"
      class="full-width q-mt-md"
      label="Se déconnecter"
      :loading="submitting"
      @click="onLogout"
    />
  </q-page>
</template>
