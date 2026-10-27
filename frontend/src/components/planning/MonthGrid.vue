<script setup lang="ts">
import { computed } from 'vue'
import {
  memberColor,
  type CalendarEvent,
  type RotationWeek,
} from '../../lib/calendar'
import { clock, todayIso } from '../../lib/dates'
import { eventBounds, laneCount, layoutWeek, type SpanSource } from '../../lib/spans'

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

type Chip = {
  key: string
  label: string
  color: string
  event: CalendarEvent | null
  rotation: RotationWeek | null
}

type Bar = SpanSource & {
  event: CalendarEvent | null
  rotation: RotationWeek | null
}

const multiDay = computed(() => {
  const rotations = props.rotations
    .filter((rotation) => rotation.ends_on > rotation.starts_on)
    .map((rotation): Bar => ({
      key: `rotation-${rotation.id}-${rotation.starts_on}`,
      label: `${rotation.title} · ${rotation.user.first_name}`,
      color: memberColor(rotation.user.id),
      start: rotation.starts_on,
      end: rotation.ends_on,
      event: null,
      rotation,
    }))
  const events = props.events.flatMap((event) => {
    const bounds = eventBounds(event)
    if (bounds.end <= bounds.start) return []
    return [{
      key: `event-${event.id}-${event.occurrence_on}`,
      label: event.all_day ? event.title : `${clock(event.starts_at)} ${event.title}`,
      color: '',
      start: bounds.start,
      end: bounds.end,
      event,
      rotation: null,
    } satisfies Bar]
  })
  return [...rotations, ...events]
})

const weeks = computed(() => {
  const rows: string[][] = []
  for (let index = 0; index < props.days.length; index += 7) {
    const slice = props.days.slice(index, index + 7)
    if (slice.length > 0) rows.push(slice)
  }
  return rows.map((days) => {
    const bars = layoutWeek(multiDay.value, days)
    return { days, bars, rows: laneCount(bars) + 2 }
  })
})

function chips(day: string): Chip[] {
  const rotations = props.rotations
    .filter((rotation) => rotation.starts_on === day && rotation.ends_on === day)
    .map((rotation): Chip => ({
      key: `rotation-${rotation.id}-${rotation.starts_on}`,
      label: `${rotation.title} · ${rotation.user.first_name}`,
      color: memberColor(rotation.user.id),
      event: null,
      rotation,
    }))
  const events = props.events
    .filter((event) => {
      const bounds = eventBounds(event)
      return bounds.start === day && bounds.end === day
    })
    .slice()
    .sort((a, b) => a.starts_at.localeCompare(b.starts_at))
    .map((event): Chip => ({
      key: `event-${event.id}-${event.occurrence_on}`,
      label: event.all_day ? event.title : `${clock(event.starts_at)} ${event.title}`,
      color: '',
      event,
      rotation: null,
    }))
  return [...rotations, ...events]
}

function openChip(chip: Chip) {
  if (chip.event) emit('openEvent', chip.event)
  else if (chip.rotation) emit('openRotation', chip.rotation)
}

function openBar(bar: Bar) {
  if (bar.event) emit('openEvent', bar.event)
  else if (bar.rotation) emit('openRotation', bar.rotation)
}
</script>

<template>
  <div class="calendar">
    <div class="month-head">
      <span v-for="label in labels" :key="label">{{ label }}</span>
    </div>
    <div class="month">
      <div v-for="week in weeks" :key="week.days[0]" class="week-row">
        <div
          v-for="(day, index) in week.days"
          :key="day"
          class="day-cell"
          :class="{ outside: !day.startsWith(month) }"
          :style="{ gridColumn: index + 1, gridRow: `1 / span ${week.rows}` }"
          @click="emit('openDay', day)"
        />
        <button
          v-for="(day, index) in week.days"
          :key="`n-${day}`"
          type="button"
          class="day-number"
          :class="{ outside: !day.startsWith(month), today: day === today }"
          :style="{ gridColumn: index + 1, gridRow: 1 }"
          @click.stop="emit('openDay', day)"
        >
          {{ Number(day.slice(8)) }}
        </button>
        <button
          v-for="bar in week.bars"
          :key="`${bar.key}-${week.days[0]}`"
          type="button"
          class="span-bar"
          :class="{ rotation: bar.rotation, continued: !bar.first, 'continues-after': bar.continuesAfter }"
          :style="{
            gridColumn: `${bar.startCol} / ${bar.endCol}`,
            gridRow: bar.lane + 1,
            background: bar.color || undefined,
          }"
          :title="bar.label"
          :aria-label="bar.label"
          @click.stop="openBar(bar)"
        >
          {{ bar.first ? bar.label : '' }}
        </button>
        <div
          v-for="(day, index) in week.days"
          :key="`c-${day}`"
          class="day-chips"
          :class="{ outside: !day.startsWith(month) }"
          :style="{ gridColumn: index + 1, gridRow: week.rows }"
          @click="emit('openDay', day)"
        >
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
  </div>
</template>
