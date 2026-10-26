<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { Notify } from 'quasar'
import { useRoute, useRouter } from 'vue-router'
import ProfileForm from '../components/ProfileForm.vue'
import { useAuth } from '../composables/useAuth'
import { ApiError } from '../lib/api'
import { fetchProfile, saveProfile, type Profile, type ProfileFields } from '../lib/profiles'

const route = useRoute()
const router = useRouter()
const { user, updateUser } = useAuth()
const profile = ref<Profile | null>(null)
const errors = ref<string[]>([])
const loading = ref(true)
const submitting = ref(false)

onMounted(load)

async function load() {
  if (!user.value) return
  loading.value = true
  errors.value = []
  try {
    profile.value = await fetchProfile(String(route.params.id), user.value.id)
  } catch (error) {
    errors.value = error instanceof ApiError ? error.errors : ['Impossible de charger le profil']
  } finally {
    loading.value = false
  }
}

async function onSubmit(fields: ProfileFields) {
  if (!user.value) return
  errors.value = []
  submitting.value = true
  try {
    const saved = await saveProfile(String(route.params.id), user.value.id, fields)
    updateUser({
      first_name: saved.first_name,
      last_name: saved.last_name,
      date_of_birth: saved.date_of_birth,
      avatar_url: saved.avatar_url,
    })
    Notify.create({ message: 'Profil enregistré' })
    await router.push({ name: 'coloc-profile', params: { id: route.params.id, userId: saved.id } })
  } catch (error) {
    errors.value = error instanceof ApiError ? error.errors : ['Impossible d’enregistrer le profil']
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <q-page class="page">
    <div class="row items-center no-wrap q-mb-md">
      <q-btn
        flat
        round
        icon="arrow_back"
        aria-label="Retour"
        :to="{ name: 'coloc-profile', params: { id: route.params.id, userId: user?.id } }"
      />
      <h1 class="settings-heading">Profil</h1>
      <span class="toolbar-spacer" aria-hidden="true" />
    </div>
    <div v-if="loading" class="row justify-center q-pa-lg">
      <q-spinner color="primary" size="32px" />
    </div>
    <ProfileForm
      v-else-if="profile"
      :first-name="profile.first_name"
      :last-name="profile.last_name"
      :description="profile.description"
      :mood="profile.mood"
      :pronouns="profile.pronouns"
      :date-of-birth="profile.date_of_birth"
      :arrived-on="profile.arrived_on"
      :avatar-url="profile.avatar_url"
      submit-label="Enregistrer"
      :submitting="submitting"
      @submit="onSubmit"
    />
    <q-banner v-if="errors.length" class="bg-negative text-white q-mt-md" rounded>
      <div v-for="(message, index) in errors" :key="index">{{ message }}</div>
    </q-banner>
  </q-page>
</template>
