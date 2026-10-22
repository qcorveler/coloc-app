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
  <main class="screen">
    <h1>Connexion</h1>
    <p class="lead">Retrouve la coloc.</p>
    <form @submit.prevent="onSubmit">
      <label>
        Email
        <input v-model="email" type="email" autocomplete="email" required />
      </label>
      <label>
        Mot de passe
        <input v-model="password" type="password" autocomplete="current-password" required minlength="8" />
      </label>
      <ul v-if="errors.length" class="errors">
        <li v-for="(message, index) in errors" :key="index">{{ message }}</li>
      </ul>
      <button type="submit" :disabled="submitting">Se connecter</button>
    </form>
    <p class="switch">
      Pas encore de compte ?
      <RouterLink :to="{ path: '/signup', query: route.query }">Créer un compte</RouterLink>
    </p>
  </main>
</template>
