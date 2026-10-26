<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useQuasar } from 'quasar'
import { useAuth } from '../composables/useAuth'
import { ApiError } from '../lib/api'
import { initial, listColocs, type ColocSummary } from '../lib/colocs'

const route = useRoute()
const router = useRouter()
const $q = useQuasar()
const { user, logout } = useAuth()

const drawer = ref(false)
const colocs = ref<ColocSummary[]>([])
const errors = ref<string[]>([])
const loggingOut = ref(false)

const colocId = computed(() => String(route.params.id))
const current = computed(() => colocs.value.find((coloc) => String(coloc.id) === colocId.value) ?? null)
const isHome = computed(() => route.name === 'coloc-home')
const isOwnProfile = computed(() => (
  route.name === 'coloc-profile' &&
  user.value != null &&
  String(route.params.userId) === String(user.value.id)
))
const barClass = computed(() => ($q.dark.isActive ? 'bg-dark text-white' : 'bg-white text-dark'))

watch(colocId, (id) => {
  void load(id)
}, { immediate: true })

async function load(id: string) {
  errors.value = []
  try {
    const list = await listColocs()
    if (id !== colocId.value) return
    colocs.value = list
    if (!list.some((coloc) => String(coloc.id) === id)) {
      await router.replace('/')
    }
  } catch (error) {
    if (id !== colocId.value) return
    errors.value = error instanceof ApiError ? error.errors : ['Impossible de charger tes colocs']
  }
}

function openColoc(id: number) {
  drawer.value = false
  if (String(id) === colocId.value) return
  const name = route.name === 'coloc-planning' ? 'coloc-planning' : 'coloc-home'
  void router.push({ name, params: { id } })
}

async function onLogout() {
  loggingOut.value = true
  try {
    await logout()
    drawer.value = false
    await router.push('/login')
  } finally {
    loggingOut.value = false
  }
}
</script>

<template>
  <q-layout view="hHh Lpr fFf">
    <q-header bordered :class="barClass">
      <q-toolbar>
        <q-btn flat round icon="menu" aria-label="Menu" @click="drawer = true" />
        <q-toolbar-title class="coloc-title">{{ current?.name ?? '' }}</q-toolbar-title>
        <q-btn
          v-if="isHome"
          flat
          round
          icon="settings"
          aria-label="Paramètres"
          :to="`/colocs/${colocId}/modifier`"
        />
        <q-btn
          v-else-if="isOwnProfile"
          flat
          round
          icon="settings"
          aria-label="Paramètres"
          :to="{ name: 'coloc-profile-edit', params: { id: colocId } }"
        />
        <span v-else class="toolbar-spacer" aria-hidden="true" />
      </q-toolbar>
    </q-header>

    <q-drawer v-model="drawer" overlay side="left" bordered :width="300">
      <div class="drawer-panel column">
        <q-list class="drawer-list q-pt-sm">
          <q-item
            v-for="coloc in colocs"
            :key="coloc.id"
            clickable
            :active="String(coloc.id) === colocId"
            active-class="text-primary"
            @click="openColoc(coloc.id)"
          >
            <q-item-section avatar>
              <q-avatar v-if="coloc.photo_url" size="40px" rounded>
                <img :src="coloc.photo_url" alt="" />
              </q-avatar>
              <q-avatar v-else size="40px" rounded color="primary" text-color="white">
                {{ initial(coloc.name) }}
              </q-avatar>
            </q-item-section>
            <q-item-section>
              <q-item-label>{{ coloc.name }}</q-item-label>
              <q-item-label caption>{{ coloc.address }}</q-item-label>
            </q-item-section>
            <q-item-section v-if="String(coloc.id) === colocId" side>
              <q-icon name="check" color="primary" />
            </q-item-section>
          </q-item>
        </q-list>
        <q-separator />
        <q-list>
          <q-item clickable to="/colocs/nouvelle" @click="drawer = false">
            <q-item-section avatar>
              <q-icon name="add" />
            </q-item-section>
            <q-item-section>Créer une coloc</q-item-section>
          </q-item>
          <q-item
            v-if="user"
            clickable
            :to="{ name: 'coloc-profile', params: { id: colocId, userId: user.id } }"
            @click="drawer = false"
          >
            <q-item-section avatar>
              <q-avatar v-if="user.avatar_url" size="40px">
                <img :src="user.avatar_url" alt="" />
              </q-avatar>
              <q-avatar v-else size="40px" color="primary" text-color="white">
                {{ initial(user.first_name) }}
              </q-avatar>
            </q-item-section>
            <q-item-section>
              <q-item-label>{{ user.first_name }} {{ user.last_name }}</q-item-label>
              <q-item-label caption>Profil</q-item-label>
            </q-item-section>
          </q-item>
          <q-item clickable :disable="loggingOut" @click="onLogout">
            <q-item-section avatar>
              <q-icon name="logout" />
            </q-item-section>
            <q-item-section>Se déconnecter</q-item-section>
          </q-item>
        </q-list>
      </div>
    </q-drawer>

    <q-page-container>
      <q-banner v-if="errors.length" class="bg-negative text-white q-ma-md" rounded>
        <div v-for="(message, index) in errors" :key="index">{{ message }}</div>
      </q-banner>
      <RouterView :key="colocId" />
    </q-page-container>

    <q-footer bordered class="coloc-footer" :class="barClass">
      <q-tabs no-caps active-color="primary" indicator-color="primary" align="justify">
        <q-route-tab :to="{ name: 'coloc-home', params: { id: colocId } }" exact icon="home" label="Accueil" />
        <q-route-tab :to="{ name: 'coloc-planning', params: { id: colocId } }" icon="calendar_month" label="Planning" />
      </q-tabs>
    </q-footer>
  </q-layout>
</template>
