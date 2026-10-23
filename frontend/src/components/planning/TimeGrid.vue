<script setup lang="ts">
import { onMounted, ref } from 'vue'
import {
  intervalOnDay,
  memberColor,
  overlapsDay,
  type CalendarEvent,
  type RotationWeek,
} from '../../lib/calendar'
import { clock, formatShort } from '../../lib/dates'

const props = defineProps<{
  days: string[]
  events: CalendarEvent[]
  rotations: RotationWeek[]
  single: boolean
}>()

const emit = defineEmits<{
  openDay: [day: string]
  openEvent: [event: CalendarEvent]
  openRotation: [rotation: RotationWeek]
}>()

const HOUR_HEIGHT = 48
const hours = Array.from({ length: 24 }, (_, hour) => hour)
const scroller = ref<HTMLElement | null>(null)

onMounted(() => {
  if (scroller.value) scroller.value.scrollTop = 7 * HOUR_HEIGHT
})

function allDay(day: string) {
  return props.events.filter((event) => event.all_day && overlapsDay(event.starts_at, event.ends_at, day))
}

function rotationsOn(day: string) {
  return props.rotations.filter((rotation) => day >= rotation.starts_on && day <= rotation.ends_on)
}

function timedOn(day: string) {
  const items = props.events
    .filter((event) => !event.all_day)
    .flatMap((event) => {
      const interval = intervalOnDay(event.starts_at, event.ends_at, day)
      return interval ? [{ event, ...interval }] : []
    })
    .sort((a, b) => a.start - b.start || b.end - a.end)

  return layout(items)
}

function layout(items: { event: CalendarEvent; start: number; end: number }[]) {
  const groups: typeof items[] = []
  let group: typeof items = []
  let groupEnd = -1
  for (const item of items) {
    if (group.length > 0 && item.start >= groupEnd) {
      groups.push(group)
      group = []
      groupEnd = -1
    }
    group.push(item)
    groupEnd = Math.max(groupEnd, item.end)
  }
  if (group.length > 0) groups.push(group)

  return groups.flatMap((current) => {
    const columnEnds: number[] = []
    const placed = current.map((item) => {
      let column = columnEnds.findIndex((end) => end <= item.start)
      if (column === -1) {
        column = columnEnds.length
        columnEnds.push(item.end)
      } else {
        columnEnds[column] = item.end
      }
      return { ...item, column }
    })
    return placed.map((item) => ({ ...item, columns: columnEnds.length }))
  })
}

function blockStyle(item: { start: number; end: number; column: number; columns: number }) {
  const width = 100 / item.columns
  return {
    top: `${(item.start / 60) * HOUR_HEIGHT}px`,
    height: `${Math.max(((item.end - item.start) / 60) * HOUR_HEIGHT, 22)}px`,
    left: `calc(${item.column * width}% + 2px)`,
    width: `calc(${width}% - 4px)`,
  }
}
</script>

<template>
  <div class="time-scroll">
    <div class="time-grid" :class="{ single }" :style="{ '--days': String(days.length) }">
      <div class="time-head">
        <div></div>
        <button v-for="day in days" :key="day" type="button" class="day-number" @click="emit('openDay', day)">
          {{ formatShort(day) }}
        </button>
      </div>
      <div class="all-day">
        <div class="gutter">Journée</div>
        <div v-for="day in days" :key="`all-${day}`" class="all-day-cell">
          <button
            v-for="event in allDay(day)"
            :key="`${event.id}-${event.occurrence_on}`"
            type="button"
            class="chip"
            :title="event.title"
            @click="emit('openEvent', event)"
          >
            {{ event.title }}
          </button>
          <button
            v-for="rotation in rotationsOn(day)"
            :key="`${rotation.id}-${rotation.starts_on}`"
            type="button"
            class="chip rotation"
            :style="{ background: memberColor(rotation.user.id) }"
            :title="`${rotation.title} · ${rotation.user.first_name}`"
            @click="emit('openRotation', rotation)"
          >
            {{ rotation.title }} · {{ rotation.user.first_name }}
          </button>
        </div>
      </div>
      <div ref="scroller" class="hour-pane">
        <div class="hour-body">
          <div class="gutter hours">
            <div v-for="hour in hours" :key="hour" class="hour-label">{{ hour }} h</div>
          </div>
          <div v-for="day in days" :key="`col-${day}`" class="day-col">
            <button
              v-for="item in timedOn(day)"
              :key="`${item.event.id}-${item.event.occurrence_on}`"
              type="button"
              class="block"
              :style="blockStyle(item)"
              @click="emit('openEvent', item.event)"
            >
              {{ clock(item.event.starts_at) }} {{ item.event.title }}
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
