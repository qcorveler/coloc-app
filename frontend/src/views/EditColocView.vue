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
  <q-page class="page">
    <h1 class="text-h4 q-mt-md q-mb-sm">Modifier la coloc</h1>
    <div v-if="loading" class="row justify-center q-pa-lg">
      <q-spinner color="primary" size="32px" />
    </div>
    <ColocForm
      v-else-if="coloc"
      :name="coloc.name"
      :address="coloc.address"
      :description="coloc.description"
      :photo-url="coloc.photo_url"
      submit-label="Enregistrer"
      :submitting="submitting"
      @submit="onSubmit"
    />
    <q-banner v-if="errors.length" class="bg-negative text-white q-mt-md" rounded>
      <div v-for="(message, index) in errors" :key="index">{{ message }}</div>
    </q-banner>
    <q-btn flat no-caps color="primary" class="q-mt-lg" label="Retour" :to="`/colocs/${route.params.id}`" />
  </q-page>
</template>
