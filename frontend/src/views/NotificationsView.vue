<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import { ApiError } from '../lib/api'
import {
  applicationServerKey,
  deletePushSubscription,
  ensureServiceWorker,
  fetchPushConfig,
  installedApp,
  iosBrowser,
  pushSupported,
  savePushSubscription,
} from '../lib/push'

const route = useRoute()
const colocId = computed(() => String(route.params.id))
const loading = ref(true)
const busy = ref(false)
const enabled = ref(false)
const publicKey = ref<string | null>(null)
const error = ref('')

const needsInstall = computed(() => iosBrowser() && !installedApp())
const supported = computed(() => pushSupported())

onMounted(load)

async function load() {
  loading.value = true
  error.value = ''
  try {
    if (!supported.value || needsInstall.value) {
      const config = await fetchPushConfig()
      publicKey.value = config.public_key
      return
    }
    const registration = await ensureServiceWorker()
    const existing = await registration.pushManager.getSubscription()
    const config = await fetchPushConfig(existing?.endpoint)
    publicKey.value = config.public_key
    enabled.value = existing !== null
  } catch (caught) {
    error.value = caught instanceof ApiError ? caught.errors[0] : 'Impossible de charger les notifications'
  } finally {
    loading.value = false
  }
}

async function activate() {
  if (!publicKey.value) return
  busy.value = true
  error.value = ''
  try {
    const permission = await Notification.requestPermission()
    if (permission !== 'granted') {
      error.value = 'Les notifications sont restées bloquées.'
      return
    }
    const registration = await ensureServiceWorker()
    const existing = await registration.pushManager.getSubscription()
    const subscription = existing ?? await registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: applicationServerKey(publicKey.value),
    })
    await savePushSubscription(subscription)
    enabled.value = true
  } catch (caught) {
    error.value = caught instanceof ApiError ? caught.errors[0] : 'Impossible d’activer les notifications'
  } finally {
    busy.value = false
  }
}

async function deactivate() {
  busy.value = true
  error.value = ''
  try {
    const registration = await ensureServiceWorker()
    const existing = await registration.pushManager.getSubscription()
    if (existing) {
      const endpoint = existing.endpoint
      await existing.unsubscribe()
      await deletePushSubscription(endpoint)
    }
    enabled.value = false
  } catch (caught) {
    error.value = caught instanceof ApiError ? caught.errors[0] : 'Impossible de désactiver les notifications'
  } finally {
    busy.value = false
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
        :to="{ name: 'coloc-home', params: { id: colocId } }"
      />
      <h1 class="settings-heading">Notifications</h1>
      <span class="toolbar-spacer" aria-hidden="true" />
    </div>

    <div v-if="loading" class="row justify-center q-pa-lg">
      <q-spinner color="primary" size="32px" />
    </div>
    <div v-else class="column q-gutter-md">
      <p class="q-my-none">
        Les rappels partent à 19 h, pour le lendemain : les événements auxquels tu es inscrit, et le jour où ton tour commence.
      </p>
      <q-banner v-if="needsInstall" class="bg-grey-3 text-dark" rounded>
        Sur iPhone, ajoute Coloc à l’écran d’accueil, puis rouvre l’application depuis cette icône pour autoriser les notifications.
      </q-banner>
      <q-banner v-else-if="!supported" class="bg-grey-3 text-dark" rounded>
        Ce navigateur ne peut pas recevoir de notifications.
      </q-banner>
      <q-banner v-else-if="!publicKey" class="bg-grey-3 text-dark" rounded>
        Les notifications ne sont pas disponibles pour le moment.
      </q-banner>
      <template v-else>
        <p v-if="enabled" class="q-my-none">Cet appareil reçoit les notifications.</p>
        <p v-else class="q-my-none">Cet appareil ne reçoit pas encore les notifications.</p>
        <q-btn
          v-if="enabled"
          outline
          no-caps
          color="primary"
          label="Désactiver"
          :loading="busy"
          @click="deactivate"
        />
        <q-btn
          v-else
          color="primary"
          unelevated
          no-caps
          label="Activer"
          :loading="busy"
          @click="activate"
        />
      </template>
      <q-banner v-if="error" class="bg-negative text-white" rounded>{{ error }}</q-banner>
    </div>
  </q-page>
</template>
