<script setup lang="ts">
import { computed, ref } from 'vue'
import { ApiError } from '../../lib/api'
import { saveRotation, type RotationWeek } from '../../lib/calendar'
import type { ColocMember } from '../../lib/colocs'

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
const startsOn = ref(props.rotation?.rule_starts_on ?? props.initialDate)
const turnDays = ref(props.rotation?.turn_days ?? 7)
const offsetDays = ref(props.rotation?.offset_days ?? 0)
const memberIds = ref<number[]>(props.rotation?.member_ids ?? props.members.map((member) => member.id))
const errors = ref<string[]>([])
const submitting = ref(false)

const available = computed(() => props.members.filter((member) => !memberIds.value.includes(member.id)))

function memberName(id: number) {
  const member = props.members.find((item) => item.id === id)
  return member ? `${member.first_name} ${member.last_name}` : 'Membre'
}

function optionsFor(currentId: number) {
  return props.members
    .filter((member) => member.id === currentId || !memberIds.value.includes(member.id))
    .map((member) => ({ label: memberName(member.id), value: member.id }))
}

function requiredRule(value: string | number | null | undefined) {
  return (value !== null && value !== undefined && value !== '') || 'Champ requis'
}

function turnRule(value: number | string | null | undefined) {
  const count = Number(value)
  return Number.isInteger(count) && count >= 1 && count <= 366 || 'Entre 1 et 366 jours'
}

function offsetRule(value: number | string | null | undefined) {
  const count = Number(value)
  return Number.isInteger(count) && count >= 0 && count <= 366 || 'Entre 0 et 366 jours'
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

function replace(index: number, value: number | string | null) {
  const id = Number(value)
  if (!Number.isInteger(id) || id <= 0) return
  const copy = [...memberIds.value]
  copy[index] = id
  memberIds.value = copy
}

async function submit() {
  const turn = Number(turnDays.value)
  const offset = Number(offsetDays.value)
  if (memberIds.value.length === 0) {
    errors.value = ['Le tour doit désigner au moins une personne']
    return
  }
  if (!Number.isInteger(turn) || turn < 1 || turn > 366 || !Number.isInteger(offset) || offset < 0 || offset > 366) {
    errors.value = ['La durée ou la pause est invalide']
    return
  }
  submitting.value = true
  errors.value = []
  try {
    await saveRotation(props.colocId, props.rotation?.id ?? null, {
      title: title.value,
      starts_on: startsOn.value,
      ends_on: null,
      turn_days: turn,
      offset_days: offset,
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
  <q-form class="column q-gutter-md" @submit.prevent="submit">
    <h2 class="text-h6 q-my-none">{{ rotation ? 'Modifier le tour' : 'Nouveau tour' }}</h2>
    <p class="muted q-mb-none">
      Les personnes se relaient dans l’ordre, sans date de fin. Chacune garde le tour pendant la durée choisie, puis la pause, puis la suivante.
    </p>
    <q-input v-model="title" label="Titre" outlined maxlength="80" lazy-rules :rules="[requiredRule]" />
    <q-input v-model="startsOn" type="date" label="Date de début" outlined lazy-rules :rules="[requiredRule]" />
    <q-input
      v-model.number="turnDays"
      type="number"
      label="Durée d’un passage (jours)"
      outlined
      min="1"
      max="366"
      lazy-rules
      :rules="[turnRule]"
    />
    <q-input
      v-model.number="offsetDays"
      type="number"
      label="Pause entre deux personnes (jours)"
      outlined
      hint="Jours vides insérés après chaque passage. 0 enchaîne tout de suite."
      min="0"
      max="366"
      lazy-rules
      :rules="[offsetRule]"
    />
    <div v-for="(id, index) in memberIds" :key="id" class="column q-gutter-xs">
      <q-select
        :model-value="id"
        :options="optionsFor(id)"
        emit-value
        map-options
        outlined
        dense
        label="Personne"
        @update:model-value="replace(index, $event)"
      />
      <div class="row q-gutter-xs">
        <q-btn dense flat no-caps color="primary" label="Monter" :disable="index === 0" @click="move(index, -1)" />
        <q-btn
          dense
          flat
          no-caps
          color="primary"
          label="Descendre"
          :disable="index === memberIds.length - 1"
          @click="move(index, 1)"
        />
        <q-btn dense flat no-caps color="negative" label="Retirer" @click="remove(index)" />
      </div>
    </div>
    <div class="row q-gutter-sm">
      <q-btn
        v-for="member in available"
        :key="member.id"
        outline
        no-caps
        color="primary"
        :label="`Ajouter ${member.first_name}`"
        @click="add(member.id)"
      />
    </div>
    <q-banner v-if="errors.length" class="bg-negative text-white" rounded>
      <div v-for="(message, index) in errors" :key="index">{{ message }}</div>
    </q-banner>
    <q-btn type="submit" color="primary" unelevated no-caps class="full-width" label="Enregistrer" :loading="submitting" />
    <q-btn outline no-caps color="primary" class="full-width" label="Annuler" @click="emit('cancel')" />
  </q-form>
</template>
