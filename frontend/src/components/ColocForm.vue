<script setup lang="ts">
import { ref, watch } from 'vue'

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

function onPhoto(value: File | File[] | null) {
  const file = Array.isArray(value) ? value[0] ?? null : value
  photo.value = file
  if (file) removePhoto.value = false
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
    <q-input v-model="name" label="Nom" outlined maxlength="80" lazy-rules :rules="[requiredRule]" />
    <q-input v-model="address" label="Adresse" outlined maxlength="200" lazy-rules :rules="[requiredRule]" />
    <q-input v-model="description" type="textarea" label="Description" outlined autogrow maxlength="5000" />
    <q-file
      :model-value="photo"
      label="Photo"
      outlined
      clearable
      accept="image/jpeg,image/png,image/webp"
      @update:model-value="onPhoto"
    />
    <q-checkbox v-if="photoUrl && !photo" v-model="removePhoto" label="Retirer la photo actuelle" />
    <q-btn type="submit" color="primary" unelevated no-caps class="full-width" :label="submitLabel" :loading="submitting" />
  </q-form>
</template>
