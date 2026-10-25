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

function requiredRule(value: string | null | undefined) {
  return !!value || 'Champ requis'
}

function onAnchor(value: string | number | null) {
  if (typeof value === 'string' && value) anchor.value = mondayOf(value)
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
  <q-form class="column q-gutter-md" @submit.prevent="submit">
    <h2 class="text-h6 q-my-none">{{ rotation ? 'Modifier le tour' : 'Nouveau tour' }}</h2>
    <p class="muted q-mb-none">Chaque personne de la liste prend une semaine, puis on recommence.</p>
    <p v-if="rotation" class="muted q-mb-none">
      Si l’ordre change et que la date reste la même, le cycle reprend lundi cette semaine.
    </p>
    <q-input v-model="title" label="Titre" outlined maxlength="80" lazy-rules :rules="[requiredRule]" />
    <q-input
      :model-value="anchor"
      type="date"
      label="Premier lundi"
      outlined
      lazy-rules
      :rules="[requiredRule]"
      @update:model-value="onAnchor"
    />
    <q-list bordered separator class="rounded-borders">
      <q-item v-for="(id, index) in memberIds" :key="id">
        <q-item-section>{{ index + 1 }}. {{ memberName(id) }}</q-item-section>
        <q-item-section side>
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
        </q-item-section>
      </q-item>
    </q-list>
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
