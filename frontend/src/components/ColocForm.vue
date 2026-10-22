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

function onFile(event: Event) {
  const input = event.target as HTMLInputElement
  photo.value = input.files?.[0] ?? null
  if (photo.value) removePhoto.value = false
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
  <form @submit.prevent="onSubmit">
    <label>
      Nom
      <input v-model="name" type="text" required maxlength="80" />
    </label>
    <label>
      Adresse
      <input v-model="address" type="text" required maxlength="200" />
    </label>
    <label>
      Description
      <textarea v-model="description" rows="5" maxlength="5000" />
    </label>
    <label>
      Photo
      <input type="file" accept="image/jpeg,image/png,image/webp" @change="onFile" />
    </label>
    <label v-if="photoUrl && !photo" class="check">
      <input v-model="removePhoto" type="checkbox" />
      Retirer la photo actuelle
    </label>
    <button type="submit" :disabled="submitting">{{ submitLabel }}</button>
  </form>
</template>
