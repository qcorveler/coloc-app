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

function requiredRule(value: string | null | undefined) {
  return !!value || 'Champ requis'
}

const recurrenceOptions: { label: string; value: Recurrence }[] = [
  { label: 'Aucune', value: 'none' },
  { label: 'Chaque jour', value: 'daily' },
  { label: 'Chaque semaine', value: 'weekly' },
  { label: 'Chaque mois', value: 'monthly' },
]

function toggleWeekday(day: number) {
  const next = weekdays.value.includes(day)
    ? weekdays.value.filter((value) => value !== day)
    : [...weekdays.value, day].sort((a, b) => a - b)
  weekdays.value = next
  if (recurrence.value === 'weekly') shiftToWeekdays(next)
}

function onRecurrenceChange(value: Recurrence) {
  recurrence.value = value
  if (value === 'weekly' && weekdays.value.length === 0) {
    weekdays.value = [isoWeekday(startDate.value)]
  }
  if (value === 'weekly') shiftToWeekdays(weekdays.value)
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
  <q-form class="column q-gutter-md" @submit.prevent="submit">
    <h2 class="text-h6 q-my-none">{{ heading }}</h2>
    <q-input v-model="title" label="Titre" outlined maxlength="80" lazy-rules :rules="[requiredRule]" />
    <q-checkbox v-model="allDay" label="Journée entière" />
    <q-input v-model="startDate" type="date" label="Début" outlined lazy-rules :rules="[requiredRule]" />
    <q-input v-if="!allDay" v-model="startTime" type="time" label="Heure de début" outlined lazy-rules :rules="[requiredRule]" />
    <q-input v-model="endDate" type="date" label="Fin" outlined lazy-rules :rules="[requiredRule]" />
    <q-input v-if="!allDay" v-model="endTime" type="time" label="Heure de fin" outlined lazy-rules :rules="[requiredRule]" />
    <template v-if="showRepeat">
      <q-select
        v-model="recurrence"
        label="Répétition"
        outlined
        emit-value
        map-options
        :options="recurrenceOptions"
        @update:model-value="onRecurrenceChange"
      />
      <div v-if="recurrence === 'weekly'" class="row q-gutter-xs">
        <q-btn
          v-for="day in WEEKDAY_OPTIONS"
          :key="day.value"
          dense
          no-caps
          color="primary"
          :unelevated="weekdays.includes(day.value)"
          :outline="!weekdays.includes(day.value)"
          :label="day.label"
          @click="toggleWeekday(day.value)"
        />
      </div>
      <q-input v-if="recurrence !== 'none'" v-model="untilOn" type="date" label="Jusqu’au" outlined />
    </template>
    <q-input v-model="notes" type="textarea" label="Notes" outlined autogrow maxlength="2000" />
    <q-banner v-if="errors.length" class="bg-negative text-white" rounded>
      <div v-for="(message, index) in errors" :key="index">{{ message }}</div>
    </q-banner>
    <q-btn type="submit" color="primary" unelevated no-caps class="full-width" label="Enregistrer" :loading="submitting" />
    <q-btn outline no-caps color="primary" class="full-width" label="Annuler" @click="emit('cancel')" />
  </q-form>
</template>
