<script setup lang="ts">
import { computed, ref } from 'vue'
import { ApiError } from '../../lib/api'
import { saveRotation, type RotationWeek } from '../../lib/calendar'
import type { ColocMember } from '../../lib/colocs'
import { mondayOf } from '../../lib/dates'

const props = defineProps<{
  colocId: string
  members: ColocMember[]
  rotation: RotationWeek | null
  initialDate: string
}>()

const emit = defineEmits<{
  saved: []
  cancel: []
}>()

const title = ref(props.rotation?.title ?? 'Ménage')
const anchor = ref(props.rotation?.anchor_on ?? mondayOf(props.initialDate))
const memberIds = ref<number[]>(props.rotation?.member_ids ?? props.members.map((member) => member.id))
const errors = ref<string[]>([])
const submitting = ref(false)

const available = computed(() => props.members.filter((member) => !memberIds.value.includes(member.id)))

function memberName(id: number) {
  const member = props.members.find((item) => item.id === id)
  return member ? `${member.first_name} ${member.last_name}` : 'Membre'
}

function onAnchor(event: Event) {
  const value = (event.target as HTMLInputElement).value
  if (value) anchor.value = mondayOf(value)
}

function move(index: number, direction: number) {
  const next = index + direction
  if (next < 0 || next >= memberIds.value.length) return
  const copy = [...memberIds.value]
  const [item] = copy.splice(index, 1)
  copy.splice(next, 0, item)
  memberIds.value = copy
}

function remove(index: number) {
  memberIds.value = memberIds.value.filter((_, current) => current !== index)
}

function add(id: number) {
  memberIds.value = [...memberIds.value, id]
}

async function submit() {
  if (memberIds.value.length === 0) {
    errors.value = ['Le tour doit désigner au moins une personne']
    return
  }
  submitting.value = true
  errors.value = []
  try {
    await saveRotation(props.colocId, props.rotation?.id ?? null, {
      title: title.value,
      anchor_on: anchor.value,
      member_ids: memberIds.value,
    })
    emit('saved')
  } catch (error) {
    errors.value = error instanceof ApiError ? error.errors : ['Impossible d’enregistrer le tour']
    submitting.value = false
  }
}
</script>

<template>
  <form @submit.prevent="submit">
    <h2>{{ rotation ? 'Modifier le tour' : 'Nouveau tour' }}</h2>
    <p class="muted">Chaque personne de la liste prend une semaine, puis on recommence.</p>
    <p v-if="rotation" class="muted">
      Si l’ordre change et que la date reste la même, le cycle reprend lundi cette semaine.
    </p>
    <label>
      Titre
      <input v-model="title" type="text" maxlength="80" required />
    </label>
    <label>
      Premier lundi
      <input :value="anchor" type="date" required @change="onAnchor" />
    </label>
    <ol class="rotation-order">
      <li v-for="(id, index) in memberIds" :key="id">
        <span>{{ index + 1 }}. {{ memberName(id) }}</span>
        <span class="member-actions">
          <button type="button" :disabled="index === 0" @click="move(index, -1)">Monter</button>
          <button type="button" :disabled="index === memberIds.length - 1" @click="move(index, 1)">Descendre</button>
          <button type="button" @click="remove(index)">Retirer</button>
        </span>
      </li>
    </ol>
    <div class="weekday-row">
      <button v-for="member in available" :key="member.id" type="button" @click="add(member.id)">
        Ajouter {{ member.first_name }}
      </button>
    </div>
    <ul v-if="errors.length" class="errors">
      <li v-for="(message, index) in errors" :key="index">{{ message }}</li>
    </ul>
    <button type="submit" class="primary" :disabled="submitting">Enregistrer</button>
    <button type="button" class="secondary" @click="emit('cancel')">Annuler</button>
  </form>
</template>
