<script setup lang="ts">
import { ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuth } from '../composables/useAuth'
import { ApiError } from '../lib/api'
import { internalPath } from '../lib/redirect'

const route = useRoute()
const router = useRouter()
const { signup } = useAuth()

const firstName = ref('')
const lastName = ref('')
const email = ref('')
const dateOfBirth = ref('')
const password = ref('')
const passwordConfirmation = ref('')
const errors = ref<string[]>([])
const submitting = ref(false)

const maxBirthDate = yesterday()

function yesterday() {
  const date = new Date()
  date.setDate(date.getDate() - 1)
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${date.getFullYear()}-${month}-${day}`
}

function requiredRule(value: string | null | undefined) {
  return !!value || 'Champ requis'
}

function passwordRule(value: string | null | undefined) {
  return (value?.length ?? 0) >= 8 || '8 caractères minimum'
}

async function onSubmit() {
  errors.value = []
  if (password.value !== passwordConfirmation.value) {
    errors.value = ['Le mot de passe ne correspond pas']
    return
  }

  submitting.value = true
  try {
    await signup({
      email: email.value,
      password: password.value,
      password_confirmation: passwordConfirmation.value,
      first_name: firstName.value,
      last_name: lastName.value,
      date_of_birth: dateOfBirth.value,
    })
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
    <h1 class="text-h4 q-mt-md q-mb-sm">Créer un compte</h1>
    <p class="q-mb-lg">Un compte personnel, la coloc viendra ensuite.</p>
    <q-form class="column q-gutter-md" @submit.prevent="onSubmit">
      <q-input v-model="firstName" label="Prénom" outlined autocomplete="given-name" lazy-rules :rules="[requiredRule]" />
      <q-input v-model="lastName" label="Nom" outlined autocomplete="family-name" lazy-rules :rules="[requiredRule]" />
      <q-input v-model="email" type="email" label="Email" outlined autocomplete="email" lazy-rules :rules="[requiredRule]" />
      <q-input
        v-model="dateOfBirth"
        type="date"
        label="Date de naissance"
        outlined
        autocomplete="bday"
        :max="maxBirthDate"
        lazy-rules
        :rules="[requiredRule]"
      />
      <q-input
        v-model="password"
        type="password"
        label="Mot de passe"
        outlined
        autocomplete="new-password"
        lazy-rules
        :rules="[requiredRule, passwordRule]"
      />
      <q-input
        v-model="passwordConfirmation"
        type="password"
        label="Confirmation"
        outlined
        autocomplete="new-password"
        lazy-rules
        :rules="[requiredRule, passwordRule]"
      />
      <q-banner v-if="errors.length" class="bg-negative text-white" rounded>
        <div v-for="(message, index) in errors" :key="index">{{ message }}</div>
      </q-banner>
      <q-btn type="submit" color="primary" unelevated no-caps class="full-width" label="Créer mon compte" :loading="submitting" />
    </q-form>
    <p class="q-mt-lg">
      Déjà un compte ?
      <RouterLink class="text-primary" :to="{ path: '/login', query: route.query }">Se connecter</RouterLink>
    </p>
  </q-page>
</template>
