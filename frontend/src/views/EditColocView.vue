<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { Notify } from 'quasar'
import { useRoute, useRouter } from 'vue-router'
import ColocForm from '../components/ColocForm.vue'
import { useAuth } from '../composables/useAuth'
import { ApiError } from '../lib/api'
import { confirm } from '../lib/confirm'
import {
  fetchColoc,
  inviteLink,
  leaveColoc,
  regenerateInvite,
  saveColoc,
  type Coloc,
  type ColocFields,
} from '../lib/colocs'
import { entryPath } from '../lib/lastColoc'

const route = useRoute()
const router = useRouter()
const { user } = useAuth()
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
  } catch (error) {
    errors.value = error instanceof ApiError ? error.errors : ['Impossible de quitter la coloc']
    submitting.value = false
    return
  }
  try {
    await router.push(user.value ? await entryPath(user.value.id) : '/')
  } catch {
    await router.push('/')
  }
}
</script>

<template>
  <q-page class="page">
    <div class="row items-center no-wrap q-mb-md">
      <q-btn flat round icon="arrow_back" aria-label="Retour" :to="`/colocs/${route.params.id}`" />
      <h1 class="settings-heading">Paramètres</h1>
      <span class="toolbar-spacer" aria-hidden="true" />
    </div>
    <div v-if="loading" class="row justify-center q-pa-lg">
      <q-spinner color="primary" size="32px" />
    </div>
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
      <div class="column q-gutter-sm q-mt-lg">
        <q-btn color="primary" unelevated no-caps label="Copier le lien d’invitation" :disable="submitting" @click="copyLink" />
        <q-btn outline no-caps color="primary" label="Régénérer le lien" :disable="submitting" @click="refreshLink" />
      </div>
      <q-btn
        outline
        no-caps
        color="negative"
        class="full-width q-mt-xl"
        label="Quitter la coloc"
        :disable="submitting"
        @click="leave"
      />
    </template>
    <q-banner v-if="errors.length" class="bg-negative text-white q-mt-md" rounded>
      <div v-for="(message, index) in errors" :key="index">{{ message }}</div>
    </q-banner>
  </q-page>
</template>
