<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { ApiError } from '../../lib/api'
import { saveEvent, type CalendarEvent, type EventInput, type Recurrence } from '../../lib/calendar'
import {
  WEEKDAY_OPTIONS,
  addDays,
  alignToWeekday,
  clock,
  dayDelta,
  inclusiveEndDate,
  isoWeekday,
  parisDate,
} from '../../lib/dates'

const props = defineProps<{
  colocId: string
  mode: 'create' | 'occurrence' | 'series'
  event: CalendarEvent | null
  initialDate: string
}>()

const emit = defineEmits<{
  saved: []
  cancel: []
}>()

const initial = buildInitial()
const title = ref(initial.title)
const notes = ref(initial.notes)
const allDay = ref(initial.allDay)
const startDate = ref(initial.startDate)
const endDate = ref(initial.endDate)
const startTime = ref(initial.startTime)
const endTime = ref(initial.endTime)
const recurrence = ref<Recurrence>(initial.recurrence)
const weekdays = ref<number[]>(initial.weekdays)
const untilOn = ref(initial.untilOn)
const errors = ref<string[]>([])
const submitting = ref(false)

const showRepeat = computed(() => props.mode !== 'occurrence')
const heading = computed(() => {
  if (props.mode === 'create') return 'Nouvel événement'
  if (props.mode === 'occurrence') return 'Modifier ce jour-ci'
  return props.event?.recurring ? 'Modifier la série' : 'Modifier l’événement'
})

watch(allDay, (value) => {
  if (!value && startTime.value === '00:00' && endTime.value === '00:00') {
    startTime.value = '18:00'
    endTime.value = '19:00'
  }
})

function buildInitial() {
  if (props.mode === 'series' && props.event) {
    return fieldsFrom(
      props.event.series_title,
      props.event.series_notes ?? '',
      props.event.series_all_day,
      props.event.series_starts_at,
      props.event.series_ends_at,
      props.event.recurrence,
      props.event.weekdays,
      props.event.until_on ?? '',
    )
  }
  if (props.event) {
    return fieldsFrom(
      props.event.title,
      props.event.notes ?? '',
      props.event.all_day,
      props.event.starts_at,
      props.event.ends_at,
      'none',
      [],
      '',
    )
  }
  return fieldsFrom('', '', false, `${props.initialDate}T18:00:00`, `${props.initialDate}T19:00:00`, 'none', [], '')
}

function fieldsFrom(
  eventTitle: string,
  eventNotes: string,
  eventAllDay: boolean,
  startsAt: string,
  endsAt: string,
  eventRecurrence: Recurrence,
  eventWeekdays: number[],
  eventUntil: string,
) {
  return {
    title: eventTitle,
    notes: eventNotes,
    allDay: eventAllDay,
    startDate: parisDate(startsAt),
    endDate: eventAllDay ? inclusiveEndDate(endsAt) : parisDate(endsAt),
    startTime: clock(startsAt) || '18:00',
    endTime: clock(endsAt) || '19:00',
    recurrence: props.mode === 'occurrence' ? 'none' as Recurrence : eventRecurrence,
    weekdays: [...eventWeekdays],
    untilOn: eventUntil,
  }
}

function toggleWeekday(day: number) {
  const next = weekdays.value.includes(day)
    ? weekdays.value.filter((value) => value !== day)
    : [...weekdays.value, day].sort((a, b) => a - b)
  weekdays.value = next
  if (recurrence.value === 'weekly') shiftToWeekdays(next)
}

function onRecurrenceChange() {
  if (recurrence.value === 'weekly' && weekdays.value.length === 0) {
    weekdays.value = [isoWeekday(startDate.value)]
  }
  if (recurrence.value === 'weekly') shiftToWeekdays(weekdays.value)
}

function shiftToWeekdays(days: number[]) {
  const aligned = alignToWeekday(startDate.value, days)
  const delta = dayDelta(startDate.value, aligned)
  if (delta === 0) return
  startDate.value = aligned
  endDate.value = addDays(endDate.value, delta)
}

async function submit() {
  submitting.value = true
  errors.value = []
  let starts = startDate.value
  let ends = endDate.value
  let days = [...weekdays.value]
  if (showRepeat.value && recurrence.value === 'weekly') {
    if (days.length === 0) days = [isoWeekday(starts)]
    const aligned = alignToWeekday(starts, days)
    const delta = dayDelta(starts, aligned)
    starts = aligned
    ends = addDays(ends, delta)
    startDate.value = starts
    endDate.value = ends
    weekdays.value = days
  }

  const fields: EventInput = {
    title: title.value,
    notes: notes.value,
    all_day: allDay.value,
    starts_at: allDay.value ? starts : `${starts}T${startTime.value}`,
    ends_at: allDay.value ? ends : `${ends}T${endTime.value}`,
    recurrence: showRepeat.value ? recurrence.value : 'none',
    weekdays: showRepeat.value && recurrence.value === 'weekly' ? days : [],
    until_on: showRepeat.value && recurrence.value !== 'none' && untilOn.value ? untilOn.value : null,
  }

  try {
    await saveEvent(
      props.colocId,
      props.mode === 'create' ? null : props.event?.id ?? null,
      fields,
      props.mode === 'occurrence' ? props.event?.occurrence_on : undefined,
    )
    emit('saved')
  } catch (error) {
    errors.value = error instanceof ApiError ? error.errors : ['Impossible d’enregistrer l’événement']
    submitting.value = false
  }
}
</script>

<template>
  <form @submit.prevent="submit">
    <h2>{{ heading }}</h2>
    <label>
      Titre
      <input v-model="title" type="text" maxlength="80" required />
    </label>
    <label class="check">
      <input v-model="allDay" type="checkbox" />
      Journée entière
    </label>
    <label>
      Début
      <input v-model="startDate" type="date" required />
      <input v-if="!allDay" v-model="startTime" type="time" required />
    </label>
    <label>
      Fin
      <input v-model="endDate" type="date" required />
      <input v-if="!allDay" v-model="endTime" type="time" required />
    </label>
    <template v-if="showRepeat">
      <label>
        Répétition
        <select v-model="recurrence" @change="onRecurrenceChange">
          <option value="none">Aucune</option>
          <option value="daily">Chaque jour</option>
          <option value="weekly">Chaque semaine</option>
          <option value="monthly">Chaque mois</option>
        </select>
      </label>
      <div v-if="recurrence === 'weekly'" class="weekday-row">
        <button
          v-for="day in WEEKDAY_OPTIONS"
          :key="day.value"
          type="button"
          :class="{ selected: weekdays.includes(day.value) }"
          @click="toggleWeekday(day.value)"
        >
          {{ day.label }}
        </button>
      </div>
      <label v-if="recurrence !== 'none'">
        Jusqu’au
        <input v-model="untilOn" type="date" />
      </label>
    </template>
    <label>
      Notes
      <textarea v-model="notes" maxlength="2000" />
    </label>
    <ul v-if="errors.length" class="errors">
      <li v-for="(message, index) in errors" :key="index">{{ message }}</li>
    </ul>
    <button type="submit" class="primary" :disabled="submitting">Enregistrer</button>
    <button type="button" class="secondary" @click="emit('cancel')">Annuler</button>
  </form>
</template>
