<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '../composables/useAuth'
import { ApiError } from '../lib/api'

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
    await router.push('/')
  } catch (error) {
    errors.value = error instanceof ApiError ? error.errors : ['Une erreur est survenue']
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <main class="screen">
    <h1>Créer un compte</h1>
    <p class="lead">Un compte personnel, la coloc viendra ensuite.</p>
    <form @submit.prevent="onSubmit">
      <label>
        Prénom
        <input v-model="firstName" type="text" autocomplete="given-name" required />
      </label>
      <label>
        Nom
        <input v-model="lastName" type="text" autocomplete="family-name" required />
      </label>
      <label>
        Email
        <input v-model="email" type="email" autocomplete="email" required />
      </label>
      <label>
        Date de naissance
        <input v-model="dateOfBirth" type="date" autocomplete="bday" :max="maxBirthDate" required />
      </label>
      <label>
        Mot de passe
        <input v-model="password" type="password" autocomplete="new-password" required minlength="8" />
      </label>
      <label>
        Confirmation
        <input v-model="passwordConfirmation" type="password" autocomplete="new-password" required minlength="8" />
      </label>
      <ul v-if="errors.length" class="errors">
        <li v-for="(message, index) in errors" :key="index">{{ message }}</li>
      </ul>
      <button type="submit" :disabled="submitting">Créer mon compte</button>
    </form>
    <p class="switch">
      Déjà un compte ?
      <RouterLink to="/login">Se connecter</RouterLink>
    </p>
  </main>
</template>
