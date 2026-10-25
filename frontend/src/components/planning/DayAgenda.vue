<script setup lang="ts">
import { computed } from 'vue'
import { memberColor, overlapsDay, type CalendarEvent, type RotationWeek } from '../../lib/calendar'
import { clock } from '../../lib/dates'

const props = defineProps<{
  day: string
  events: CalendarEvent[]
  rotations: RotationWeek[]
}>()

const emit = defineEmits<{
  openEvent: [event: CalendarEvent]
  openRotation: [rotation: RotationWeek]
}>()

type AgendaRow = {
  key: string
  when: string
  label: string
  color: string
  event: CalendarEvent | null
  rotation: RotationWeek | null
}

const rows = computed(() => {
  const rotations = props.rotations
    .filter((rotation) => props.day >= rotation.starts_on && props.day <= rotation.ends_on)
    .map((rotation): AgendaRow => ({
      key: `rotation-${rotation.id}-${rotation.starts_on}`,
      when: 'Journée',
      label: `${rotation.title} · ${rotation.user.first_name}`,
      color: memberColor(rotation.user.id),
      event: null,
      rotation,
    }))

  const allDay = props.events
    .filter((event) => event.all_day && overlapsDay(event.starts_at, event.ends_at, props.day))
    .map((event): AgendaRow => ({
      key: `event-${event.id}-${event.occurrence_on}`,
      when: 'Journée',
      label: event.title,
      color: '',
      event,
      rotation: null,
    }))

  const timed = props.events
    .filter((event) => !event.all_day && overlapsDay(event.starts_at, event.ends_at, props.day))
    .slice()
    .sort((a, b) => a.starts_at.localeCompare(b.starts_at))
    .map((event): AgendaRow => ({
      key: `event-${event.id}-${event.occurrence_on}`,
      when: `${clock(event.starts_at)} – ${clock(event.ends_at)}`,
      label: event.title,
      color: '',
      event,
      rotation: null,
    }))

  return [...rotations, ...allDay, ...timed]
})

function open(row: AgendaRow) {
  if (row.event) emit('openEvent', row.event)
  else if (row.rotation) emit('openRotation', row.rotation)
}
</script>

<template>
  <q-list v-if="rows.length" bordered separator class="rounded-borders">
    <q-item v-for="row in rows" :key="row.key" clickable @click="open(row)">
      <q-item-section side class="agenda-when" :style="row.color ? { color: row.color } : undefined">
        {{ row.when }}
      </q-item-section>
      <q-item-section>
        <q-item-label>{{ row.label }}</q-item-label>
      </q-item-section>
    </q-item>
  </q-list>
  <p v-else class="text-grey-7">Rien de prévu ce jour.</p>
</template>
