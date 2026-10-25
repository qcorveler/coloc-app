<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import { ApiError } from '../lib/api'
import { fetchColoc, initial, type Coloc } from '../lib/colocs'

const route = useRoute()
const coloc = ref<Coloc | null>(null)
const errors = ref<string[]>([])
const loading = ref(true)

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

function memberCaption(count: number) {
  return count > 1 ? `${count} colocataires` : `${count} colocataire`
}
</script>

<template>
  <q-page class="page">
    <div v-if="loading" class="row justify-center q-pa-lg">
      <q-spinner color="primary" size="32px" />
    </div>
    <template v-else-if="coloc">
      <q-img v-if="coloc.photo_url" :src="coloc.photo_url" :alt="coloc.name" :ratio="16 / 9" class="rounded-borders" />
      <div v-else class="banner-fallback">{{ initial(coloc.name) }}</div>
      <h1 class="text-h5 q-mt-md q-mb-sm">{{ coloc.name }}</h1>
      <p class="muted">{{ coloc.address }}</p>
      <p class="q-my-md">{{ coloc.description || 'Pas encore de description.' }}</p>
      <p class="muted q-mb-sm">{{ memberCaption(coloc.members.length) }}</p>
      <q-list>
        <q-item v-for="member in coloc.members" :key="member.id" class="q-px-none">
          <q-item-section avatar>
            <q-avatar color="primary" text-color="white" size="40px">
              {{ initial(member.first_name) }}
            </q-avatar>
          </q-item-section>
          <q-item-section>{{ member.first_name }} {{ member.last_name }}</q-item-section>
        </q-item>
      </q-list>
    </template>
    <q-banner v-if="errors.length" class="bg-negative text-white q-mt-md" rounded>
      <div v-for="(message, index) in errors" :key="index">{{ message }}</div>
    </q-banner>
  </q-page>
</template>
