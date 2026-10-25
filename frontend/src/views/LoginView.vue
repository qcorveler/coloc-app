<script setup lang="ts">
import { ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuth } from '../composables/useAuth'
import { ApiError } from '../lib/api'
import { internalPath } from '../lib/redirect'

const route = useRoute()
const router = useRouter()
const { login } = useAuth()

const email = ref('')
const password = ref('')
const errors = ref<string[]>([])
const submitting = ref(false)

function requiredRule(value: string | null | undefined) {
  return !!value || 'Champ requis'
}

function passwordRule(value: string | null | undefined) {
  return (value?.length ?? 0) >= 8 || '8 caractères minimum'
}

async function onSubmit() {
  errors.value = []
  submitting.value = true
  try {
    await login(email.value, password.value)
    await router.push(internalPath(route.query.redirect) ?? '/')
  } catch (error) {
    errors.value = error instanceof ApiError ? error.errors : ['Une erreur est survenue']
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <q-page class="page">
    <h1 class="text-h4 q-mt-md q-mb-sm">Connexion</h1>
    <p class="q-mb-lg">Retrouve la coloc.</p>
    <q-form class="column q-gutter-md" @submit.prevent="onSubmit">
      <q-input
        v-model="email"
        type="email"
        label="Email"
        outlined
        autocomplete="email"
        lazy-rules
        :rules="[requiredRule]"
      />
      <q-input
        v-model="password"
        type="password"
        label="Mot de passe"
        outlined
        autocomplete="current-password"
        lazy-rules
        :rules="[requiredRule, passwordRule]"
      />
      <q-banner v-if="errors.length" class="bg-negative text-white" rounded>
        <div v-for="(message, index) in errors" :key="index">{{ message }}</div>
      </q-banner>
      <q-btn type="submit" color="primary" unelevated no-caps class="full-width" label="Se connecter" :loading="submitting" />
    </q-form>
    <p class="q-mt-lg">
      Pas encore de compte ?
      <RouterLink class="text-primary" :to="{ path: '/signup', query: route.query }">Créer un compte</RouterLink>
    </p>
  </q-page>
</template>
