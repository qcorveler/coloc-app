<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue'
import { initial } from '../lib/colocs'

const props = defineProps<{
  name?: string
  address?: string
  description?: string | null
  photoUrl?: string | null
  submitLabel: string
  submitting: boolean
}>()

const emit = defineEmits<{
  submit: [payload: {
    name: string
    address: string
    description: string
    photo: File | null
    removePhoto: boolean
  }]
}>()

const name = ref(props.name ?? '')
const address = ref(props.address ?? '')
const description = ref(props.description ?? '')
const photo = ref<File | null>(null)
const removePhoto = ref(false)
const objectUrl = ref<string | null>(null)
const picker = ref<HTMLInputElement | null>(null)

const previewUrl = computed(() => {
  if (objectUrl.value) return objectUrl.value
  if (removePhoto.value) return null
  return props.photoUrl ?? null
})

watch(
  () => [props.name, props.address, props.description, props.photoUrl],
  () => {
    name.value = props.name ?? ''
    address.value = props.address ?? ''
    description.value = props.description ?? ''
  },
)

function requiredRule(value: string | null | undefined) {
  return !!value || 'Champ requis'
}

onBeforeUnmount(clearObjectUrl)

function openPicker() {
  picker.value?.click()
}

function onPick(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  input.value = ''
  if (!file) return
  clearObjectUrl()
  photo.value = file
  objectUrl.value = URL.createObjectURL(file)
  removePhoto.value = false
}

function clearObjectUrl() {
  if (!objectUrl.value) return
  URL.revokeObjectURL(objectUrl.value)
  objectUrl.value = null
}

function onSubmit() {
  emit('submit', {
    name: name.value,
    address: address.value,
    description: description.value,
    photo: photo.value,
    removePhoto: removePhoto.value,
  })
}
</script>

<template>
  <q-form class="column q-gutter-md" @submit.prevent="onSubmit">
    <button type="button" class="photo-picker banner" aria-label="Changer la photo" @click="openPicker">
      <img v-if="previewUrl" :src="previewUrl" alt="" />
      <div v-else class="banner-fallback">{{ initial(name) }}</div>
      <span class="photo-picker-badge" aria-hidden="true">
        <q-icon name="photo_camera" size="18px" />
      </span>
    </button>
    <input ref="picker" class="photo-picker-input" type="file" accept="image/jpeg,image/png,image/webp" @change="onPick" />
    <q-checkbox v-if="photoUrl && !photo" v-model="removePhoto" label="Retirer la photo actuelle" />
    <q-input v-model="name" label="Nom" outlined maxlength="80" lazy-rules :rules="[requiredRule]" />
    <q-input v-model="address" label="Adresse" outlined maxlength="200" lazy-rules :rules="[requiredRule]" />
    <q-input v-model="description" type="textarea" label="Description" outlined autogrow maxlength="5000" />
    <q-btn type="submit" color="primary" unelevated no-caps class="full-width" :label="submitLabel" :loading="submitting" />
  </q-form>
</template>
