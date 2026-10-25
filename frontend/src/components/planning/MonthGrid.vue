<script setup lang="ts">
import { overlapsDay, type CalendarEvent, type RotationWeek, memberColor } from '../../lib/calendar'
import { clock, todayIso } from '../../lib/dates'

const props = defineProps<{
  month: string
  days: string[]
  events: CalendarEvent[]
  rotations: RotationWeek[]
}>()

const emit = defineEmits<{
  openDay: [day: string]
  openEvent: [event: CalendarEvent]
  openRotation: [rotation: RotationWeek]
}>()

const labels = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.']
const today = todayIso()

function chips(day: string) {
  const rotations = props.rotations
    .filter((rotation) => day >= rotation.starts_on && day <= rotation.ends_on)
    .map((rotation) => ({
      key: `rotation-${rotation.id}-${rotation.starts_on}`,
      label: `${rotation.title} · ${rotation.user.first_name}`,
      color: memberColor(rotation.user.id),
      rotation,
      event: null as CalendarEvent | null,
    }))
  const events = props.events
    .filter((event) => overlapsDay(event.starts_at, event.ends_at, day))
    .slice()
    .sort((a, b) => a.starts_at.localeCompare(b.starts_at))
    .map((event) => ({
      key: `event-${event.id}-${event.occurrence_on}`,
      label: event.all_day ? event.title : `${clock(event.starts_at)} ${event.title}`,
      color: '',
      rotation: null as RotationWeek | null,
      event,
    }))
  return [...rotations, ...events]
}

function openChip(chip: ReturnType<typeof chips>[number]) {
  if (chip.event) emit('openEvent', chip.event)
  else if (chip.rotation) emit('openRotation', chip.rotation)
}
</script>

<template>
  <div class="calendar">
    <div class="month-head">
      <span v-for="label in labels" :key="label">{{ label }}</span>
    </div>
    <div class="month">
      <div
        v-for="day in days"
        :key="day"
        class="day-cell"
        :class="{ outside: !day.startsWith(month), today: day === today }"
        @click="emit('openDay', day)"
      >
        <button type="button" class="day-number" @click.stop="emit('openDay', day)">
          {{ Number(day.slice(8)) }}
        </button>
        <button
          v-for="chip in chips(day).slice(0, 3)"
          :key="chip.key"
          type="button"
          class="chip"
          :class="{ rotation: chip.rotation }"
          :style="chip.color ? { background: chip.color } : undefined"
          :title="chip.label"
          @click.stop="openChip(chip)"
        >
          {{ chip.label }}
        </button>
        <button
          v-if="chips(day).length > 3"
          type="button"
          class="more"
          @click.stop="emit('openDay', day)"
        >
          + {{ chips(day).length - 3 }}
        </button>
      </div>
    </div>
  </div>
</template>
