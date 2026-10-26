<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue'
import { addDays, todayIso } from '../lib/dates'
import type { ProfileFields } from '../lib/profiles'

const props = defineProps<{
  firstName: string
  lastName: string
  description?: string | null
  mood?: string | null
  pronouns?: string | null
  dateOfBirth: string
  arrivedOn: string
  avatarUrl?: string | null
  submitLabel: string
  submitting: boolean
}>()

const emit = defineEmits<{
  submit: [payload: ProfileFields]
}>()

const pronounOptions = [
  { label: 'Il', value: 'il' },
  { label: 'Elle', value: 'elle' },
  { label: 'Autre', value: 'autre' },
]

const firstName = ref(props.firstName)
const lastName = ref(props.lastName)
const description = ref(props.description ?? '')
const mood = ref(props.mood ?? '')
const dateOfBirth = ref(props.dateOfBirth)
const arrivedOn = ref(props.arrivedOn)
const pronounChoice = ref<string | null>(pronounMode(props.pronouns))
const customPronouns = ref(props.pronouns && props.pronouns !== 'il' && props.pronouns !== 'elle' ? props.pronouns : '')
const avatar = ref<File | null>(null)
const removeAvatar = ref(false)
const objectUrl = ref<string | null>(null)
const picker = ref<HTMLInputElement | null>(null)

const maxBirthDate = addDays(todayIso(), -1)
const maxArrivalDate = todayIso()
const previewUrl = computed(() => {
  if (objectUrl.value) return objectUrl.value
  if (removeAvatar.value) return null
  return props.avatarUrl ?? null
})

watch(
  () => [props.firstName, props.lastName, props.description, props.mood, props.pronouns, props.dateOfBirth, props.arrivedOn],
  () => {
    firstName.value = props.firstName
    lastName.value = props.lastName
    description.value = props.description ?? ''
    mood.value = props.mood ?? ''
    dateOfBirth.value = props.dateOfBirth
    arrivedOn.value = props.arrivedOn
    pronounChoice.value = pronounMode(props.pronouns)
    customPronouns.value = props.pronouns && props.pronouns !== 'il' && props.pronouns !== 'elle' ? props.pronouns : ''
  },
)

onBeforeUnmount(clearObjectUrl)

function pronounMode(value: string | null | undefined) {
  if (value === 'il' || value === 'elle') return value
  if (value) return 'autre'
  return null
}

function requiredRule(value: string | null | undefined) {
  return !!value || 'Champ requis'
}

function customPronounRule(value: string | null | undefined) {
  if (pronounChoice.value !== 'autre') return true
  return !!value?.trim() || 'Indique tes pronoms'
}

function openPicker() {
  picker.value?.click()
}

function onPick(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  input.value = ''
  if (!file) return
  clearObjectUrl()
  avatar.value = file
  objectUrl.value = URL.createObjectURL(file)
  removeAvatar.value = false
}

function clearObjectUrl() {
  if (!objectUrl.value) return
  URL.revokeObjectURL(objectUrl.value)
  objectUrl.value = null
}

function pronounsValue() {
  if (pronounChoice.value === 'il' || pronounChoice.value === 'elle') return pronounChoice.value
  if (pronounChoice.value === 'autre') return customPronouns.value.trim()
  return ''
}

function onSubmit() {
  emit('submit', {
    first_name: firstName.value,
    last_name: lastName.value,
    description: description.value,
    mood: mood.value,
    pronouns: pronounsValue(),
    date_of_birth: dateOfBirth.value,
    arrived_on: arrivedOn.value,
    avatar: avatar.value,
    removeAvatar: removeAvatar.value,
  })
}
</script>

<template>
  <q-form class="column q-gutter-md" @submit.prevent="onSubmit">
    <button type="button" class="photo-picker round" aria-label="Changer la photo" @click="openPicker">
      <q-avatar v-if="previewUrl" size="96px">
        <img :src="previewUrl" alt="" />
      </q-avatar>
      <q-avatar v-else size="96px" color="primary" text-color="white" class="text-h4">
        {{ firstName.trim().charAt(0).toUpperCase() || '?' }}
      </q-avatar>
      <span class="photo-picker-badge" aria-hidden="true">
        <q-icon name="photo_camera" size="16px" />
      </span>
    </button>
    <input ref="picker" class="photo-picker-input" type="file" accept="image/jpeg,image/png,image/webp" @change="onPick" />
    <q-checkbox v-if="avatarUrl && !avatar" v-model="removeAvatar" label="Retirer la photo actuelle" />
    <q-input v-model="firstName" label="Prénom" outlined maxlength="80" lazy-rules :rules="[requiredRule]" />
    <q-input v-model="lastName" label="Nom" outlined maxlength="80" lazy-rules :rules="[requiredRule]" />
    <q-input v-model="description" type="textarea" label="Description" outlined autogrow maxlength="500" />
    <q-input v-model="mood" label="Humeur" outlined maxlength="40" />
    <div>
      <div class="q-mb-xs">Pronoms</div>
      <q-option-group v-model="pronounChoice" :options="pronounOptions" inline color="primary" />
      <q-input
        v-if="pronounChoice === 'autre'"
        v-model="customPronouns"
        class="q-mt-sm"
        label="Pronoms"
        outlined
        maxlength="40"
        lazy-rules
        :rules="[customPronounRule]"
      />
    </div>
    <q-input
      v-model="arrivedOn"
      type="date"
      label="Date d'arrivée"
      outlined
      :max="maxArrivalDate"
      lazy-rules
      :rules="[requiredRule]"
    />
    <q-input
      v-model="dateOfBirth"
      type="date"
      label="Date d'anniversaire"
      outlined
      :max="maxBirthDate"
      lazy-rules
      :rules="[requiredRule]"
    />
    <q-btn type="submit" color="primary" unelevated no-caps class="full-width" :label="submitLabel" :loading="submitting" />
  </q-form>
</template>
