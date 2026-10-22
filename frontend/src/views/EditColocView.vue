<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import ColocForm from '../components/ColocForm.vue'
import { ApiError } from '../lib/api'
import { fetchColoc, saveColoc, type Coloc, type ColocFields } from '../lib/colocs'

const route = useRoute()
const router = useRouter()
const coloc = ref<Coloc | null>(null)
const errors = ref<string[]>([])
const loading = ref(true)
const submitting = ref(false)

onMounted(async () => {
  try {
    coloc.value = await fetchColoc(String(route.params.id))
  } catch (error) {
    errors.value = error instanceof ApiError ? error.errors : ['Impossible de charger la coloc']
  } finally {
    loading.value = false
  }
})

async function onSubmit(fields: ColocFields) {
  errors.value = []
  submitting.value = true
  try {
    const updated = await saveColoc(Number(route.params.id), fields)
    await router.push(`/colocs/${updated.id}`)
  } catch (error) {
    errors.value = error instanceof ApiError ? error.errors : ['Impossible d’enregistrer la coloc']
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <main class="screen">
    <h1>Modifier la coloc</h1>
    <p v-if="loading" class="lead">Chargement…</p>
    <template v-else-if="coloc">
      <ColocForm
        :name="coloc.name"
        :address="coloc.address"
        :description="coloc.description"
        :photo-url="coloc.photo_url"
        submit-label="Enregistrer"
        :submitting="submitting"
        @submit="onSubmit"
      />
    </template>
    <ul v-if="errors.length" class="errors">
      <li v-for="(message, index) in errors" :key="index">{{ message }}</li>
    </ul>
    <p class="switch"><RouterLink :to="`/colocs/${route.params.id}`">Retour</RouterLink></p>
  </main>
</template>
