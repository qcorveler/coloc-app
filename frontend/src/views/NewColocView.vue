<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import ColocForm from '../components/ColocForm.vue'
import { ApiError } from '../lib/api'
import { saveColoc, type ColocFields } from '../lib/colocs'

const router = useRouter()
const errors = ref<string[]>([])
const submitting = ref(false)

async function onSubmit(fields: ColocFields) {
  errors.value = []
  submitting.value = true
  try {
    const coloc = await saveColoc(null, fields)
    await router.push(`/colocs/${coloc.id}`)
  } catch (error) {
    errors.value = error instanceof ApiError ? error.errors : ['Impossible de créer la coloc']
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <q-page class="page">
    <h1 class="text-h4 q-mt-md q-mb-sm">Nouvelle coloc</h1>
    <p class="q-mb-lg">Un nom et une adresse suffisent. La photo peut venir plus tard.</p>
    <ColocForm submit-label="Créer la coloc" :submitting="submitting" @submit="onSubmit" />
    <q-banner v-if="errors.length" class="bg-negative text-white q-mt-md" rounded>
      <div v-for="(message, index) in errors" :key="index">{{ message }}</div>
    </q-banner>
    <q-btn flat no-caps color="primary" class="q-mt-lg" label="Retour" to="/" />
  </q-page>
</template>
