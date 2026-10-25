<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '../composables/useAuth'
import { ApiError } from '../lib/api'
import { listColocs } from '../lib/colocs'
import { resolveColocEntry } from '../lib/lastColoc'

const router = useRouter()
const { user, logout } = useAuth()
const loading = ref(true)
const errors = ref<string[]>([])
const submitting = ref(false)

onMounted(async () => {
  let redirecting = false
  try {
    const colocs = await listColocs()
    const next = user.value ? resolveColocEntry(user.value.id, colocs) : null
    if (next) {
      redirecting = true
      await router.replace(next)
      return
    }
  } catch (error) {
    redirecting = false
    errors.value = error instanceof ApiError ? error.errors : ['Impossible de charger tes colocs']
  } finally {
    if (!redirecting) loading.value = false
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
    <div v-if="loading" class="row justify-center q-pa-lg">
      <q-spinner color="primary" size="32px" />
    </div>
    <template v-else>
      <h1 class="text-h4 q-mt-md q-mb-sm">{{ errors.length ? 'Tes colocs' : 'Pas encore de coloc' }}</h1>
      <p v-if="errors.length === 0" class="q-mb-lg">Crée la tienne, ou ouvre le lien qu’un colocataire t’a envoyé.</p>
      <q-banner v-if="errors.length" class="bg-negative text-white q-mb-md" rounded>
        <div v-for="(message, index) in errors" :key="index">{{ message }}</div>
      </q-banner>
      <q-btn color="primary" unelevated no-caps class="full-width" label="Créer une coloc" to="/colocs/nouvelle" />
      <q-btn
        outline
        no-caps
        color="primary"
        class="full-width q-mt-md"
        label="Se déconnecter"
        :loading="submitting"
        @click="onLogout"
      />
    </template>
  </q-page>
</template>
