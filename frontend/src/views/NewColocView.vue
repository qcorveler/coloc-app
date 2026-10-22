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
  <main class="screen">
    <h1>Nouvelle coloc</h1>
    <p class="lead">Un nom et une adresse suffisent. La photo peut venir plus tard.</p>
    <ColocForm submit-label="Créer la coloc" :submitting="submitting" @submit="onSubmit" />
    <ul v-if="errors.length" class="errors">
      <li v-for="(message, index) in errors" :key="index">{{ message }}</li>
    </ul>
    <p class="switch"><RouterLink to="/">Retour</RouterLink></p>
  </main>
</template>
